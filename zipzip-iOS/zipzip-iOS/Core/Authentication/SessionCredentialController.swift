//
//  SessionCredentialController.swift
//  zipzip-iOS
//

import Foundation

actor SessionCredentialController {
    private let store: CredentialStore
    private let authAPI: AuthAPI

    private var storedCredential: StoredSessionCredential?
    private var refreshTask: Task<StoredSessionCredential, Error>?
    private var refreshTaskID: UUID?
    private var epoch: UInt64 = 0
    private var isTerminating = false

    init(store: CredentialStore, authAPI: AuthAPI) {
        self.store = store
        self.authAPI = authAPI
    }

    func restore() async throws -> StoredSessionCredential? {
        let restoreEpoch = epoch
        let restored = try await store.load()

        guard restoreEpoch == epoch, !isTerminating else {
            throw AuthSessionError.staleOperation
        }
        storedCredential = restored

        guard let restored else { return nil }
        if let code = restored.refreshBlockedCode {
            throw AuthSessionError.refreshBlocked(code)
        }
        if restored.pendingRefreshIdempotencyKey != nil || restored.credential.requiresRefresh {
            return try await refresh()
        }
        return restored
    }

    func current() -> StoredSessionCredential? {
        storedCredential
    }

    func credentialForRequest() async throws -> AuthCredential {
        guard !isTerminating else {
            throw AuthSessionError.staleOperation
        }
        guard let storedCredential else {
            throw AuthSessionError.missingCredential
        }
        if let code = storedCredential.refreshBlockedCode {
            throw AuthSessionError.refreshBlocked(code)
        }
        if storedCredential.pendingRefreshIdempotencyKey != nil || storedCredential.credential.requiresRefresh {
            return try await refresh().credential
        }
        return storedCredential.credential
    }

    func commitLogin(
        response: LoginResponse,
        appleUserIdentifier: String,
        developmentUserKey: String? = nil
    ) async throws -> StoredSessionCredential {
        guard !isTerminating else {
            throw AuthSessionError.staleOperation
        }
        guard response.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame else {
            throw AuthSessionError.invalidTokenType
        }

        epoch &+= 1
        let loginEpoch = epoch
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskID = nil
        let stored = StoredSessionCredential(
            credential: response.credential(),
            user: response.user,
            appleUserIdentifier: appleUserIdentifier,
            developmentUserKey: developmentUserKey
        )
        try await store.save(stored)

        guard epoch == loginEpoch, !isTerminating else {
            try? await store.delete(ifMatching: stored)
            throw AuthSessionError.staleOperation
        }
        storedCredential = stored
        return stored
    }

    func refresh() async throws -> StoredSessionCredential {
        guard !isTerminating else {
            throw AuthSessionError.staleOperation
        }
        return try await coordinatedRefresh()
    }

    func credentialAfterUnauthorized(_ rejected: AuthCredential) async throws -> AuthCredential {
        guard !isTerminating,
              let current = storedCredential
        else {
            throw AuthSessionError.missingCredential
        }
        if let code = current.refreshBlockedCode {
            throw AuthSessionError.refreshBlocked(code)
        }

        if current.credential.accessToken != rejected.accessToken,
           current.pendingRefreshIdempotencyKey == nil,
           !current.credential.requiresRefresh {
            return current.credential
        }
        return try await coordinatedRefresh().credential
    }

    func beginTermination(
        requiresFreshCredential: Bool = false,
        timeout: Duration = .seconds(3)
    ) async -> StoredSessionCredential? {
        guard !isTerminating else { return nil }
        isTerminating = true

        var terminationRefreshID: UUID?
        if refreshTask != nil
            || storedCredential?.pendingRefreshIdempotencyKey != nil
            || storedCredential?.credential.requiresRefresh == true {
            terminationRefreshID = try? startRefreshTaskIfNeeded().id
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while let terminationRefreshID,
              refreshTaskID == terminationRefreshID,
              clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        if let terminationRefreshID,
           refreshTaskID == terminationRefreshID {
            epoch &+= 1
            refreshTask?.cancel()
            refreshTask = nil
            refreshTaskID = nil
            if requiresFreshCredential {
                return nil
            }
        }

        if requiresFreshCredential,
           let current = storedCredential,
           current.pendingRefreshIdempotencyKey != nil || current.credential.requiresRefresh {
            return nil
        }
        return storedCredential
    }

    func cancelTermination() {
        isTerminating = false
    }

    private func coordinatedRefresh() async throws -> StoredSessionCredential {
        let operation = try startRefreshTaskIfNeeded()
        return try await operation.task.value
    }

    private func startRefreshTaskIfNeeded() throws -> (
        id: UUID,
        task: Task<StoredSessionCredential, Error>
    ) {
        if let refreshTask, let refreshTaskID {
            return (refreshTaskID, refreshTask)
        }
        guard let base = storedCredential else {
            throw AuthSessionError.missingCredential
        }
        if let code = base.refreshBlockedCode {
            throw AuthSessionError.refreshBlocked(code)
        }

        let operationKey = base.pendingRefreshIdempotencyKey ?? UUID()
        let capturedEpoch = epoch
        let capturedToken = base.credential.refreshToken
        let taskID = UUID()
        let task = Task { [self] in
            do {
                let refreshed = try await prepareAndPerformRefresh(
                    base: base,
                    capturedEpoch: capturedEpoch,
                    capturedToken: capturedToken,
                    operationKey: operationKey
                )
                finishRefreshTaskIfCurrent(taskID)
                return refreshed
            } catch {
                try await finishFailedRefreshIfCurrent(
                    taskID: taskID,
                    capturedEpoch: capturedEpoch,
                    capturedToken: capturedToken,
                    error: error
                )
                throw error
            }
        }
        refreshTask = task
        refreshTaskID = taskID
        return (taskID, task)
    }

    private func prepareAndPerformRefresh(
        base: StoredSessionCredential,
        capturedEpoch: UInt64,
        capturedToken: String,
        operationKey: UUID
    ) async throws -> StoredSessionCredential {
        var operationBase = base
        if base.pendingRefreshIdempotencyKey == nil {
            operationBase = StoredSessionCredential(
                credential: base.credential,
                user: base.user,
                appleUserIdentifier: base.appleUserIdentifier,
                developmentUserKey: base.developmentUserKey,
                refreshTokenVersion: base.refreshTokenVersion,
                pendingRefreshIdempotencyKey: operationKey,
                refreshBlockedCode: base.refreshBlockedCode
            )
            try await store.save(operationBase)

            guard capturedEpoch == epoch,
                  storedCredential?.credential.refreshToken == capturedToken
            else {
                try? await store.delete(ifMatching: operationBase)
                throw AuthSessionError.staleOperation
            }
            storedCredential = operationBase
        }

        return try await performRefresh(
            base: operationBase,
            capturedEpoch: capturedEpoch,
            capturedToken: capturedToken,
            operationKey: operationKey
        )
    }

    private func performRefresh(
        base: StoredSessionCredential,
        capturedEpoch: UInt64,
        capturedToken: String,
        operationKey: UUID
    ) async throws -> StoredSessionCredential {
        let response = try await refreshWithBackoff(
            refreshToken: capturedToken,
            idempotencyKey: operationKey
        )

        guard capturedEpoch == epoch,
              storedCredential?.credential.refreshToken == capturedToken
        else {
            throw AuthSessionError.staleOperation
        }
        guard response.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame else {
            throw AuthSessionError.invalidTokenType
        }

        let refreshed = StoredSessionCredential(
            credential: response.credential(),
            user: base.user,
            appleUserIdentifier: base.appleUserIdentifier,
            developmentUserKey: base.developmentUserKey,
            refreshTokenVersion: base.refreshTokenVersion + 1
        )
        try await store.save(refreshed)

        guard capturedEpoch == epoch,
              storedCredential?.credential.refreshToken == capturedToken
        else {
            try? await store.delete(ifMatching: refreshed)
            throw AuthSessionError.staleOperation
        }
        storedCredential = refreshed
        return refreshed
    }

    func clear() async throws {
        epoch &+= 1
        isTerminating = false
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskID = nil
        storedCredential = nil
        try await store.delete()
    }

    private func finishRefreshTaskIfCurrent(_ taskID: UUID) {
        guard refreshTaskID == taskID else { return }
        refreshTask = nil
        refreshTaskID = nil
    }

    private func finishFailedRefreshIfCurrent(
        taskID: UUID,
        capturedEpoch: UInt64,
        capturedToken: String,
        error: Error
    ) async throws {
        guard refreshTaskID == taskID else { return }
        let operationIsCurrent = capturedEpoch == epoch
            && storedCredential?.credential.refreshToken == capturedToken
        finishRefreshTaskIfCurrent(taskID)

        if operationIsCurrent, isTerminalRefreshError(error) {
            try await clear()
        } else if operationIsCurrent,
                  (error as? NetworkError)?.serverCode == "IDEMPOTENCY_KEY_REUSED" {
            try await blockRefresh(with: "IDEMPOTENCY_KEY_REUSED")
        }
    }

    private func blockRefresh(with code: String) async throws {
        guard let current = storedCredential else { return }
        let blockedEpoch = epoch
        let blocked = StoredSessionCredential(
            credential: current.credential,
            user: current.user,
            appleUserIdentifier: current.appleUserIdentifier,
            developmentUserKey: current.developmentUserKey,
            refreshTokenVersion: current.refreshTokenVersion,
            pendingRefreshIdempotencyKey: current.pendingRefreshIdempotencyKey,
            refreshBlockedCode: code
        )
        storedCredential = blocked
        try await store.save(blocked)

        guard blockedEpoch == epoch, storedCredential == blocked else {
            try? await store.delete(ifMatching: blocked)
            throw AuthSessionError.staleOperation
        }
    }

    private func refreshWithBackoff(
        refreshToken: String,
        idempotencyKey: UUID
    ) async throws -> TokenRefreshResponse {
        let delays: [Duration] = [.zero, .milliseconds(500), .seconds(1), .seconds(2)]
        var lastError: Error = NetworkError.noResponse

        for delay in delays {
            if delay > .zero {
                try await Task.sleep(for: delay)
            }
            do {
                return try await authAPI.refresh(
                    refreshToken: refreshToken,
                    idempotencyKey: idempotencyKey
                )
            } catch {
                lastError = error
                guard isRetryableRefreshError(error) else { throw error }
            }
        }
        throw lastError
    }

    private func isRetryableRefreshError(_ error: Error) -> Bool {
        guard let networkError = error as? NetworkError else { return false }
        if case .noResponse = networkError {
            return true
        }
        if let statusCode = networkError.statusCode,
           500 ..< 600 ~= statusCode {
            return true
        }
        return networkError.serverCode == "IDEMPOTENCY_REQUEST_IN_PROGRESS"
    }

    private func isTerminalRefreshError(_ error: Error) -> Bool {
        guard let code = (error as? NetworkError)?.serverCode else { return false }
        return [
            "INVALID_REFRESH_TOKEN",
            "REFRESH_TOKEN_EXPIRED",
            "REFRESH_TOKEN_REUSE_DETECTED",
            "USER_NOT_FOUND"
        ].contains(code)
    }
}
