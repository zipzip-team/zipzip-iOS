//
//  SharedAlbumDetailViewModel.swift
//  zipzip-iOS
//

import Foundation
import Observation
import OSLog

@MainActor
protocol SharedAlbumDetailRepository {
    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    func renameAlbum(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        name: String
    ) async throws -> Bool
    func deleteAlbum(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID
    ) async throws -> Bool
    func uploadPhotos(
        localIdentifiers: [String],
        to albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    func copyPhotosToPersonalAlbums(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to personalAlbumIDs: [Album.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    func deleteLocalCopies(
        photoIDs: [SharedAlbumPhoto.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
}

/// 서로 다른 공유 그룹/사진 Repository를 화면 전용 Repository 계약으로 묶는 어댑터.
@MainActor
struct SharedAlbumDetailRepositoryAdapter: SharedAlbumDetailRepository {
    let onCachedPhotos: (SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    let onSynchronizePhotos: (SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    let onRenameAlbum: (ShareAlbum.ID, SharedAlbum.ID, String) async throws -> Bool
    let onDeleteAlbum: (ShareAlbum.ID, SharedAlbum.ID) async throws -> Bool
    let onUploadPhotos: ([String], SharedAlbum.ID) async throws -> SharedAlbumPhotoMutationResult
    let onSavePhotosToLibrary: ([SharedAlbumPhoto.ID], SharedAlbum.ID) async throws -> SharedAlbumPhotoMutationResult
    let onCopyPhotos: (
        [SharedAlbumPhoto.ID],
        SharedAlbum.ID,
        [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    let onCopyPhotosToPersonalAlbums: (
        [SharedAlbumPhoto.ID],
        SharedAlbum.ID,
        [Album.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    let onDeleteLocalCopies: ([SharedAlbumPhoto.ID]) async throws -> SharedAlbumPhotoMutationResult
    let onDetachPhotos: (
        [SharedAlbumPhoto.ID],
        SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult

    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        try await onCachedPhotos(albumID)
    }

    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        try await onSynchronizePhotos(albumID)
    }

    func renameAlbum(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        name: String
    ) async throws -> Bool {
        try await onRenameAlbum(groupID, albumID, name)
    }

    func deleteAlbum(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID
    ) async throws -> Bool {
        try await onDeleteAlbum(groupID, albumID)
    }

    func uploadPhotos(
        localIdentifiers: [String],
        to albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onUploadPhotos(localIdentifiers, albumID)
    }

    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onSavePhotosToLibrary(photoIDs, albumID)
    }

    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onCopyPhotos(photoIDs, sourceAlbumID, destinationAlbumIDs)
    }

    func copyPhotosToPersonalAlbums(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to personalAlbumIDs: [Album.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onCopyPhotosToPersonalAlbums(photoIDs, sourceAlbumID, personalAlbumIDs)
    }

    func deleteLocalCopies(
        photoIDs: [SharedAlbumPhoto.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onDeleteLocalCopies(photoIDs)
    }

    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        try await onDetachPhotos(photoIDs, albumID)
    }
}

@Observable
@MainActor
final class SharedAlbumDetailViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "SharedAlbumDetail"
    )

    let groupID: ShareAlbum.ID
    let albumID: SharedAlbum.ID

    private(set) var photos: [SharedAlbumPhoto] = []
    private(set) var sections: [SharedAlbumPhotoSection] = []
    private(set) var selectedPhotoIDs: [SharedAlbumPhoto.ID] = []
    private(set) var selectedDestinationAlbumIDs: [SharedAlbum.ID] = []
    private(set) var selectedPersonalAlbumIDs: [Album.ID] = []

    var isSelectionMode = false
    var isPhotoPickerPresented = false
    var isAlbumManagementPresented = false
    var isAlbumDeleteAlertPresented = false
    var isCopySheetPresented = false
    var isDeleteSheetPresented = false
    var albumTitleDraft = ""

    private(set) var isRefreshing = false
    private(set) var isPerformingPhotoMutation = false
    private(set) var isUpdatingAlbum = false
    private(set) var isDeletingAlbum = false

    private var hasLoadedCache = false
    private var shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
    private var lastExpiredURLRefreshAt: Date?
    private let repository: any SharedAlbumDetailRepository
    private let onAlbumDeleted: () -> Void

    init(
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        repository: any SharedAlbumDetailRepository,
        onAlbumDeleted: @escaping () -> Void = {}
    ) {
        self.groupID = groupID
        self.albumID = albumID
        self.repository = repository
        self.onAlbumDeleted = onAlbumDeleted
    }

    var hasPhotos: Bool {
        !photos.isEmpty
    }

    var hasSelectedPhotos: Bool {
        !selectedPhotoIDs.isEmpty
    }

    var selectedPhotoCount: Int {
        selectedPhotoIDs.count
    }

    var isBusy: Bool {
        isPerformingPhotoMutation || isUpdatingAlbum || isDeletingAlbum
    }

    func load() async {
        if !hasLoadedCache {
            await loadCachedPhotos(presentsError: false)
            hasLoadedCache = true
        }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            apply(try await repository.synchronizePhotos(in: albumID))
        } catch {
            logError("failed to load shared album photos", error: error)
        }
    }

    func refreshExpiredURLsIfNeeded() async {
        guard photos.contains(where: { $0.hasExpiredRemoteURL() }) else { return }
        if let lastExpiredURLRefreshAt,
           Date.now.timeIntervalSince(lastExpiredURLRefreshAt) < 15 {
            return
        }
        lastExpiredURLRefreshAt = .now
        await refresh()
    }

    func enterSelectionMode() {
        guard !isBusy else { return }
        isSelectionMode = true
    }

    func beginSelection(with photoID: SharedAlbumPhoto.ID) {
        guard !isBusy else { return }
        isSelectionMode = true
        if !selectedPhotoIDs.contains(photoID) {
            selectedPhotoIDs.append(photoID)
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
        selectedDestinationAlbumIDs.removeAll()
        selectedPersonalAlbumIDs.removeAll()
        isCopySheetPresented = false
        isDeleteSheetPresented = false
    }

    func togglePhotoSelection(_ photoID: SharedAlbumPhoto.ID) {
        guard isSelectionMode, !isBusy else { return }
        if let index = selectedPhotoIDs.firstIndex(of: photoID) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(photoID)
        }
    }

    func presentPhotoPicker() {
        guard !isBusy else { return }
        isPhotoPickerPresented = true
    }

    func addPhotos(localIdentifiers: [String]) async -> Bool {
        guard !localIdentifiers.isEmpty, !isPerformingPhotoMutation else { return false }
        return await performPhotoMutation(
            fallbackError: "사진을 공유집에 추가하지 못했어요.",
            closesSelectionOnSuccess: false
        ) {
            try await repository.uploadPhotos(localIdentifiers: localIdentifiers, to: albumID)
        }
    }

    func presentAlbumManagement(albumTitle: String) {
        guard !isBusy else { return }
        exitSelectionMode()
        albumTitleDraft = albumTitle
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
        isAlbumManagementPresented = true
    }

    func dismissAlbumManagement() {
        guard !isUpdatingAlbum else { return }
        isAlbumManagementPresented = false
    }

    func completeAlbumManagement() async {
        let name = albumTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isUpdatingAlbum else { return }

        isUpdatingAlbum = true
        defer { isUpdatingAlbum = false }
        do {
            guard try await repository.renameAlbum(groupID: groupID, albumID: albumID, name: name) else {
                logError("failed to rename shared album")
                return
            }
            isAlbumManagementPresented = false
        } catch {
            logError("failed to rename shared album", error: error)
        }
    }

    func presentAlbumDeleteAlert() {
        guard !isUpdatingAlbum else { return }
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = true
        isAlbumManagementPresented = false
    }

    func completeAlbumManagementDismissal() {
        guard shouldPresentAlbumDeleteAlertAfterManagementDismissal else { return }
        shouldPresentAlbumDeleteAlertAfterManagementDismissal = false
        isAlbumDeleteAlertPresented = true
    }

    func dismissAlbumDeleteAlert() {
        isAlbumDeleteAlertPresented = false
    }

    func confirmAlbumDeletion() async {
        guard !isDeletingAlbum else { return }
        isDeletingAlbum = true
        defer { isDeletingAlbum = false }
        do {
            guard try await repository.deleteAlbum(groupID: groupID, albumID: albumID) else {
                logError("failed to delete shared album")
                return
            }
            isAlbumDeleteAlertPresented = false
            isAlbumManagementPresented = false
            onAlbumDeleted()
        } catch {
            logError("failed to delete shared album", error: error)
        }
    }

    func saveSelectedPhotos() async {
        let photoIDs = selectedPhotoIDs
        guard !photoIDs.isEmpty else { return }
        _ = await performPhotoMutation(fallbackError: "사진을 저장하지 못했어요.") {
            try await repository.savePhotosToLibrary(photoIDs: photoIDs, in: albumID)
        }
    }

    func presentCopySheet() {
        guard hasSelectedPhotos, !isBusy else { return }
        selectedDestinationAlbumIDs.removeAll()
        selectedPersonalAlbumIDs.removeAll()
        isCopySheetPresented = true
    }

    func dismissCopySheet() {
        guard !isPerformingPhotoMutation else { return }
        isCopySheetPresented = false
        selectedDestinationAlbumIDs.removeAll()
        selectedPersonalAlbumIDs.removeAll()
    }

    func toggleDestinationAlbum(_ albumID: SharedAlbum.ID) {
        guard !isPerformingPhotoMutation else { return }
        if let index = selectedDestinationAlbumIDs.firstIndex(of: albumID) {
            selectedDestinationAlbumIDs.remove(at: index)
        } else {
            selectedDestinationAlbumIDs.append(albumID)
        }
    }

    func togglePersonalDestinationAlbum(_ albumID: Album.ID) {
        guard !isPerformingPhotoMutation else { return }
        if let index = selectedPersonalAlbumIDs.firstIndex(of: albumID) {
            selectedPersonalAlbumIDs.remove(at: index)
        } else {
            selectedPersonalAlbumIDs.append(albumID)
        }
    }

    func clearCopySelections() {
        guard !isPerformingPhotoMutation else { return }
        selectedDestinationAlbumIDs.removeAll()
        selectedPersonalAlbumIDs.removeAll()
    }

    func copySelectedPhotos() async {
        guard !selectedDestinationAlbumIDs.isEmpty else { return }
        let destinations = selectedDestinationAlbumIDs
        _ = await performPhotoMutation(fallbackError: "사진을 다른 공유집에 복사하지 못했어요.") {
            try await repository.copyPhotos(
                photoIDs: selectedPhotoIDs,
                from: albumID,
                to: destinations
            )
        }
    }

    func copySelectedPhotosToPersonalAlbums() async {
        guard !selectedPersonalAlbumIDs.isEmpty else { return }
        let destinations = selectedPersonalAlbumIDs
        _ = await performPhotoMutation(fallbackError: "사진을 사진집에 복사하지 못했어요.") {
            try await repository.copyPhotosToPersonalAlbums(
                photoIDs: selectedPhotoIDs,
                from: albumID,
                to: destinations
            )
        }
    }

    func presentDeleteSheet() {
        guard hasSelectedPhotos, !isBusy else { return }
        isDeleteSheetPresented = true
    }

    func dismissDeleteSheet() {
        guard !isPerformingPhotoMutation else { return }
        isDeleteSheetPresented = false
    }

    func detachSelectedPhotos() async {
        guard hasSelectedPhotos else { return }
        _ = await performPhotoMutation(fallbackError: "공유집에서 사진을 제거하지 못했어요.") {
            try await repository.detachPhotos(photoIDs: selectedPhotoIDs, from: albumID)
        }
    }

    private func performPhotoMutation(
        fallbackError: String,
        closesSelectionOnSuccess: Bool = true,
        operation: () async throws -> SharedAlbumPhotoMutationResult
    ) async -> Bool {
        guard !isPerformingPhotoMutation else { return false }
        isPerformingPhotoMutation = true
        defer { isPerformingPhotoMutation = false }

        do {
            let result = try await operation()
            await loadCachedPhotos(presentsError: true)
            if result.failedCount > 0 {
                logPartialFailure(result)
            }

            let didCompleteAnyWork = result.succeededCount > 0 || result.failedCount == 0
            if didCompleteAnyWork, closesSelectionOnSuccess {
                exitSelectionMode()
            }
            return didCompleteAnyWork
        } catch {
            logError(fallbackError, error: error)
            return false
        }
    }

    private func loadCachedPhotos(presentsError: Bool) async {
        do {
            apply(try await repository.cachedPhotos(in: albumID))
        } catch {
            if presentsError {
                logError("failed to load changed shared album photos", error: error)
            }
        }
    }

    private func apply(_ photos: [SharedAlbumPhoto]) {
        self.photos = photos.sorted { lhs, rhs in
            if lhs.displayAt == rhs.displayAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.displayAt > rhs.displayAt
        }
        sections = Self.makeSections(from: self.photos)

        let availableIDs = Set(photos.map(\.id))
        selectedPhotoIDs.removeAll { !availableIDs.contains($0) }
    }

    private func logError(_ message: String, error: Error? = nil) {
        if let error {
            Self.logger.error(
                """
                ❌ [SharedAlbumDetail] \(message, privacy: .public)
                Error: \(String(describing: error), privacy: .public)
                """
            )
        } else {
            Self.logger.error("❌ [SharedAlbumDetail] \(message, privacy: .public)")
        }
    }

    private func logPartialFailure(_ result: SharedAlbumPhotoMutationResult) {
        let totalCount = result.succeededCount + result.failedCount
        Self.logger.error(
            """
            ❌ [SharedAlbumDetail] photo mutation partially failed
            Total: \(totalCount, privacy: .public)
            Succeeded: \(result.succeededCount, privacy: .public)
            Failed: \(result.failedCount, privacy: .public)
            """
        )
    }

    private static func makeSections(from photos: [SharedAlbumPhoto]) -> [SharedAlbumPhotoSection] {
        let calendar = Calendar.autoupdatingCurrent
        let referenceDate = Date.now
        let grouped = Dictionary(grouping: photos) { calendar.startOfDay(for: $0.displayAt) }

        return grouped.keys.sorted(by: >).map { date in
            SharedAlbumPhotoSection(
                id: date,
                title: sectionTitle(for: date, relativeTo: referenceDate, calendar: calendar),
                photos: grouped[date] ?? []
            )
        }
    }

    private static func sectionTitle(
        for date: Date,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "오늘"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제"
        }

        let style = Date.FormatStyle(
            locale: .autoupdatingCurrent,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        .month(.abbreviated)
        .day(.defaultDigits)

        if calendar.isDate(date, equalTo: referenceDate, toGranularity: .year) {
            return date.formatted(style)
        }
        return date.formatted(style.year(.defaultDigits))
    }
}
