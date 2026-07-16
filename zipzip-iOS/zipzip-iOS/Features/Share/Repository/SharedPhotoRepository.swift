//
//  SharedPhotoRepository.swift
//  zipzip-iOS
//

import Foundation
import OSLog

struct SharedPhotoAuthor: Equatable {
    let id: UUID?
    let displayName: String?
}

struct SharedPhotoDetail: Identifiable, Equatable {
    let id: UUID
    let sharedGroupID: UUID
    let sharedAlbumIDs: [UUID]
    let originalURL: String
    let originalURLExpiresAt: Date
    let thumbnailURL: String?
    let thumbnailURLExpiresAt: Date?
    let thumbnailStatus: String
    let deviceModel: String?
    let takenAt: Date?
    let displayAt: Date
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isInferred: Bool
    let width: Int
    let height: Int
    let uploadedBy: SharedPhotoAuthor
    let isUploader: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByMe: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SharedPhotoComment: Identifiable, Equatable, CommentSheetMessage {
    let id: UUID
    let photoID: UUID
    let content: String
    let author: SharedPhotoAuthor
    let isAuthor: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SharedPhotoCommentPage {
    let items: [SharedPhotoComment]
    let nextCursor: String?
    let hasNext: Bool
}

struct SharedPhotoLikeState: Equatable {
    let photoID: UUID
    let isLikedByMe: Bool
    let likeCount: Int
}

enum SharedPhotoRepositoryError: Error, Equatable {
    case photoNotFound
    case invalidDate
    case cacheNotPrepared
    case invalidPagination
    case invalidServerResponse
    case invalidSignedURL
    case uploadURLExpired
}

@MainActor
protocol SharedPhotoRepository {
    func prepareCache(for userID: UUID) async throws
    func invalidateCacheSession()
    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto]
    func addLocalPhotos(
        localIdentifiers: [String],
        to albumIDs: [SharedAlbum.ID],
        in groupID: ShareAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult
    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult
    func deleteLocalCopies(photoIDs: [SharedAlbumPhoto.ID]) async throws -> SharedAlbumPhotoMutationResult
    func localIdentifiers(inPersonalAlbum albumID: Album.ID) async throws -> [String]
    func localIdentifiers(forAlbumPhotoIDs albumPhotoIDs: [Int]) async throws -> [String]
    func photo(id: UUID) async throws -> SharedPhotoDetail
    func comments(photoID: UUID, cursor: String?, size: Int) async throws -> SharedPhotoCommentPage
    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment
    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState
}

@MainActor
final class DefaultSharedPhotoRepository: SharedPhotoRepository {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "SharedPhotoRepository"
    )

    private struct CacheContext {
        let ownerID: UUID
        let sessionID: UUID
    }

    private struct UploadBatchOutcome {
        let photoIDs: [UUID]
        let localIdentifiers: [String]
        let succeededCount: Int
        let failedCount: Int
    }

    private struct AttachmentOutcome {
        let succeededPhotoIDs: [UUID]
        let failedPhotoIDs: [UUID]
    }

    private let api: SharedPhotoAPI
    private let injectedStore: SharedPhotoStore?
    private let groupAPI: ShareGroupAPI?
    private let groupStore: SharedGroupStore?
    private let objectStorage: any ObjectStorageTransferClient
    private let assetPreparer: SharedPhotoAssetPreparer
    private let photoLibrary: SharedPhotoLibraryService
    private var cacheOwnerID: UUID?
    private var cacheSessionID = UUID()
    private var uploadTaskCleanup: Task<Void, Never>?

    init(
        api: SharedPhotoAPI,
        store: SharedPhotoStore? = nil,
        groupAPI: ShareGroupAPI? = nil,
        groupStore: SharedGroupStore? = nil,
        objectStorage: any ObjectStorageTransferClient = DefaultObjectStorageTransferClient(),
        assetPreparer: SharedPhotoAssetPreparer = SharedPhotoAssetPreparer(),
        photoLibrary: SharedPhotoLibraryService = SharedPhotoLibraryService()
    ) {
        self.api = api
        self.injectedStore = store
        self.groupAPI = groupAPI
        self.groupStore = groupStore
        self.objectStorage = objectStorage
        self.assetPreparer = assetPreparer
        self.photoLibrary = photoLibrary
    }

    private var store: SharedPhotoStore {
        injectedStore ?? SharedPhotoStore()
    }

    func prepareCache(for userID: UUID) async throws {
        await uploadTaskCleanup?.value
        uploadTaskCleanup = nil
        let sessionID = UUID()
        cacheSessionID = sessionID
        cacheOwnerID = nil
        try await store.prepareCache(for: userID)
        guard cacheSessionID == sessionID else {
            throw CancellationError()
        }
        cacheOwnerID = userID
        try await store.deleteExpiredUploadTasks(cacheOwnerID: userID)
    }

    func invalidateCacheSession() {
        let ownerID = cacheOwnerID
        let store = self.store
        let previousCleanup = uploadTaskCleanup
        cacheSessionID = UUID()
        cacheOwnerID = nil
        if let ownerID {
            uploadTaskCleanup = Task<Void, Never> {
                await previousCleanup?.value
                try? await store.deleteAllUploadTasks(cacheOwnerID: ownerID)
            }
        }
    }

    func cachedPhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        let context = try requiredCacheContext()
        let photos = try await store.fetchPhotos(albumID: albumID)
        try validate(context)
        return photos.map(Self.makeAlbumPhoto)
    }

    func synchronizePhotos(in albumID: SharedAlbum.ID) async throws -> [SharedAlbumPhoto] {
        let context = try requiredCacheContext()
        var cursor: String?
        var requestedCursors: Set<String> = []
        var serverPhotoIDs: Set<UUID> = []

        repeat {
            if let cursor, !requestedCursors.insert(cursor).inserted {
                throw SharedPhotoRepositoryError.invalidPagination
            }
            let page = try await api.fetchPhotos(sharedAlbumID: albumID, cursor: cursor, size: 100)
            try validate(context)
            if page.hasNext, page.nextCursor == nil {
                throw SharedPhotoRepositoryError.invalidPagination
            }
            let inputs = try page.items.map { try Self.makeStoreInput($0) }
            try await store.upsertPhotos(inputs, albumID: albumID, cacheOwnerID: context.ownerID)
            serverPhotoIDs.formUnion(page.items.map(\.id))

            let nextCursor = page.hasNext ? page.nextCursor : nil
            if page.hasNext, nextCursor == cursor {
                throw SharedPhotoRepositoryError.invalidPagination
            }
            cursor = nextCursor
        } while cursor != nil

        try validate(context)
        try await store.reconcileAlbum(
            albumID: albumID,
            serverPhotoIDs: serverPhotoIDs,
            cacheOwnerID: context.ownerID
        )
        return try await cachedPhotos(in: albumID)
    }

    func addLocalPhotos(
        localIdentifiers: [String],
        to albumIDs: [SharedAlbum.ID],
        in groupID: ShareAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        let context = try requiredCacheContext()
        let identifiers = Self.unique(localIdentifiers.filter { !$0.isEmpty })
        let destinations = Self.unique(albumIDs)
        guard !identifiers.isEmpty, let primaryAlbumID = destinations.first else {
            return SharedAlbumPhotoMutationResult(succeededCount: 0)
        }

        var existingMappings: [(localIdentifier: String, photoID: UUID)] = []
        var identifiersToUpload: [String] = []
        for identifier in identifiers {
            if let photo = try await store.fetchPhoto(groupID: groupID, localIdentifier: identifier) {
                existingMappings.append((identifier, photo.id))
            } else {
                identifiersToUpload.append(identifier)
            }
        }
        try validate(context)

        let uploadOutcome = try await uploadBatches(
            localIdentifiers: identifiersToUpload,
            groupID: groupID,
            albumID: primaryAlbumID,
            context: context
        )

        var succeededCount = uploadOutcome.succeededCount
        var failedCount = uploadOutcome.failedCount
        var candidatePhotoIDs = uploadOutcome.photoIDs
        var identifierByPhotoID = Dictionary(
            uniqueKeysWithValues: zip(uploadOutcome.photoIDs, uploadOutcome.localIdentifiers)
        )
        identifierByPhotoID.merge(
            Dictionary(uniqueKeysWithValues: existingMappings.map { ($0.photoID, $0.localIdentifier) })
        ) { current, _ in current }

        if !existingMappings.isEmpty {
            let outcome = try await attach(
                photoIDs: existingMappings.map(\.photoID),
                to: primaryAlbumID,
                context: context
            )
            candidatePhotoIDs.append(contentsOf: outcome.succeededPhotoIDs)
            succeededCount += outcome.succeededPhotoIDs.count
            failedCount += outcome.failedPhotoIDs.count
        }

        for destinationAlbumID in destinations.dropFirst() {
            let outcome = try await attach(
                photoIDs: candidatePhotoIDs,
                to: destinationAlbumID,
                context: context
            )
            let succeededIDs = Set(outcome.succeededPhotoIDs)
            candidatePhotoIDs.removeAll { !succeededIDs.contains($0) }
            failedCount += outcome.failedPhotoIDs.count
        }
        let result = SharedAlbumPhotoMutationResult(
            succeededCount: succeededCount,
            failedCount: failedCount,
            succeededLocalIdentifiers: candidatePhotoIDs.compactMap { identifierByPhotoID[$0] }
        )
        await refreshMutationState(
            groupID: groupID,
            affectedAlbumIDs: destinations,
            context: context
        )
        return result
    }

    func copyPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from sourceAlbumID: SharedAlbum.ID,
        to destinationAlbumIDs: [SharedAlbum.ID]
    ) async throws -> SharedAlbumPhotoMutationResult {
        let context = try requiredCacheContext()
        let groupID = try await store.fetchGroupID(albumID: sourceAlbumID)
        let sourcePhotoIDs = Set(try await store.fetchPhotos(albumID: sourceAlbumID).map(\.id))
        let validPhotoIDs = Self.unique(photoIDs).filter { sourcePhotoIDs.contains($0) }
        let destinations = Self.unique(destinationAlbumIDs.filter { $0 != sourceAlbumID })
        guard !validPhotoIDs.isEmpty, !destinations.isEmpty else {
            return SharedAlbumPhotoMutationResult(succeededCount: 0)
        }

        var succeededCount = 0
        var failedCount = 0
        for destination in destinations {
            let outcome = try await attach(photoIDs: validPhotoIDs, to: destination, context: context)
            succeededCount += outcome.succeededPhotoIDs.count
            failedCount += outcome.failedPhotoIDs.count
        }
        let result = SharedAlbumPhotoMutationResult(
            succeededCount: succeededCount,
            failedCount: failedCount
        )
        if let groupID {
            await refreshMutationState(
                groupID: groupID,
                affectedAlbumIDs: destinations,
                context: context
            )
        }
        return result
    }

    func detachPhotos(
        photoIDs: [SharedAlbumPhoto.ID],
        from albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        let context = try requiredCacheContext()
        let groupID = try await store.fetchGroupID(albumID: albumID)
        let uniquePhotoIDs = Self.unique(photoIDs)
        guard !uniquePhotoIDs.isEmpty else {
            return SharedAlbumPhotoMutationResult(succeededCount: 0)
        }

        var succeededIDs: [UUID] = []
        var failedCount = 0
        for chunk in uniquePhotoIDs.chunked(maxCount: 100) {
            let idempotencyKey = UUID()
            do {
                _ = try await retrying {
                    try await api.detachPhotos(
                        sharedAlbumID: albumID,
                        photoIDs: chunk,
                        idempotencyKey: idempotencyKey
                    )
                }
                try validate(context)
                try await store.removeMemberships(
                    photoIDs: chunk,
                    from: albumID,
                    cacheOwnerID: context.ownerID
                )
                succeededIDs.append(contentsOf: chunk)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedCount += chunk.count
            }
        }

        for photoID in succeededIDs {
            do {
                let response = try await api.fetchPhoto(id: photoID)
                try validate(context)
                try await store.upsertPhoto(
                    try Self.makeStoreInput(response),
                    albumIDs: [],
                    cacheOwnerID: context.ownerID
                )
            } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
                try validate(context)
                try await store.deletePhotos(ids: [photoID], cacheOwnerID: context.ownerID)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // 현재 공유집 조인은 이미 서버 응답대로 제거됐다. 상세 재검증은 다음 동기화에 맡긴다.
            }
        }

        let result = SharedAlbumPhotoMutationResult(
            succeededCount: succeededIDs.count,
            failedCount: failedCount
        )
        if let groupID {
            await refreshMutationState(
                groupID: groupID,
                affectedAlbumIDs: [albumID],
                context: context
            )
        }
        return result
    }

    func savePhotosToLibrary(
        photoIDs: [SharedAlbumPhoto.ID],
        in albumID: SharedAlbum.ID
    ) async throws -> SharedAlbumPhotoMutationResult {
        let context = try requiredCacheContext()
        let uniquePhotoIDs = Self.unique(photoIDs)
        var succeededCount = 0
        var failedCount = 0
        var succeededLocalIdentifiers: [String] = []
        var refreshedExpiredURLs = false

        for photoID in uniquePhotoIDs {
            do {
                guard var photo = try await store.fetchPhoto(id: photoID) else {
                    throw SharedPhotoRepositoryError.photoNotFound
                }
                if let localIdentifier = try await saveLocalDuplicateIfAvailable(
                    photo,
                    photoID: photoID
                ) {
                    try validate(context)
                    try await store.linkLocalPhoto(
                        sharedPhotoID: photoID,
                        localIdentifier: localIdentifier,
                        cacheOwnerID: context.ownerID
                    )
                    succeededCount += 1
                    succeededLocalIdentifiers.append(localIdentifier)
                    continue
                }

                if photo.originalURLExpiresAt <= .now {
                    if !refreshedExpiredURLs {
                        _ = try await synchronizePhotos(in: albumID)
                        refreshedExpiredURLs = true
                    }
                    guard let refreshedPhoto = try await store.fetchPhoto(id: photoID) else {
                        throw SharedPhotoRepositoryError.photoNotFound
                    }
                    photo = refreshedPhoto
                }
                guard photo.originalURLExpiresAt > .now,
                      let signedURL = URL(string: photo.originalURL)
                else {
                    throw SharedPhotoRepositoryError.invalidSignedURL
                }

                let downloadedURL: URL
                do {
                    downloadedURL = try await objectStorage.download(from: signedURL)
                } catch {
                    guard !refreshedExpiredURLs else { throw error }
                    _ = try await synchronizePhotos(in: albumID)
                    refreshedExpiredURLs = true
                    guard let refreshedPhoto = try await store.fetchPhoto(id: photoID),
                          refreshedPhoto.originalURLExpiresAt > .now,
                          let refreshedURL = URL(string: refreshedPhoto.originalURL)
                    else {
                        throw SharedPhotoRepositoryError.invalidSignedURL
                    }
                    downloadedURL = try await objectStorage.download(from: refreshedURL)
                    photo = refreshedPhoto
                }
                defer { try? FileManager.default.removeItem(at: downloadedURL) }

                let localIdentifier = try await photoLibrary.savePhoto(
                    from: downloadedURL,
                    creationDate: photo.takenAt ?? photo.createdAt,
                    latitude: photo.latitude,
                    longitude: photo.longitude
                )
                try validate(context)
                try await store.linkLocalPhoto(
                    sharedPhotoID: photoID,
                    localIdentifier: localIdentifier,
                    cacheOwnerID: context.ownerID
                )
                succeededCount += 1
                succeededLocalIdentifiers.append(localIdentifier)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Self.logger.error(
                    """
                    ❌ [SharedPhotoRepository] failed to save photo to library
                    Photo ID: \(photoID.uuidString, privacy: .public)
                    Error: \(String(describing: error), privacy: .public)
                    """
                )
                failedCount += 1
            }
        }
        return SharedAlbumPhotoMutationResult(
            succeededCount: succeededCount,
            failedCount: failedCount,
            succeededLocalIdentifiers: succeededLocalIdentifiers
        )
    }

    private func saveLocalDuplicateIfAvailable(
        _ photo: StoredSharedPhoto,
        photoID: SharedAlbumPhoto.ID
    ) async throws -> String? {
        guard let localIdentifier = photo.localIdentifier,
              photoLibrary.containsPhoto(localIdentifier: localIdentifier)
        else {
            return nil
        }

        let preparedAsset: PreparedSharedPhotoAsset
        do {
            preparedAsset = try await assetPreparer.prepare(localIdentifier: localIdentifier)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.warning(
                """
                ⚠️ [SharedPhotoRepository] failed to prepare local copy; falling back to download
                Photo ID: \(photoID.uuidString, privacy: .public)
                Error: \(String(describing: error), privacy: .public)
                """
            )
            return nil
        }

        defer { assetPreparer.removePreparedFile(preparedAsset) }
        return try await photoLibrary.savePhoto(
            from: preparedAsset.fileURL,
            creationDate: photo.takenAt ?? preparedAsset.takenAt ?? photo.createdAt,
            latitude: photo.latitude ?? preparedAsset.latitude,
            longitude: photo.longitude ?? preparedAsset.longitude
        )
    }

    func deleteLocalCopies(photoIDs: [SharedAlbumPhoto.ID]) async throws -> SharedAlbumPhotoMutationResult {
        let context = try requiredCacheContext()
        let photos = try await Self.unique(photoIDs).asyncCompactMap { photoID in
            try await store.fetchPhoto(id: photoID)
        }
        let localIdentifiers = Self.unique(photos.compactMap(\.localIdentifier).filter { !$0.isEmpty })
        guard !localIdentifiers.isEmpty else {
            return SharedAlbumPhotoMutationResult(succeededCount: 0)
        }
        try await photoLibrary.deletePhotos(localIdentifiers: localIdentifiers)
        try validate(context)
        return SharedAlbumPhotoMutationResult(succeededCount: localIdentifiers.count)
    }

    func localIdentifiers(inPersonalAlbum albumID: Album.ID) async throws -> [String] {
        _ = try requiredCacheContext()
        return try await store.fetchLocalIdentifiers(personalAlbumID: albumID)
    }

    func localIdentifiers(forAlbumPhotoIDs albumPhotoIDs: [Int]) async throws -> [String] {
        _ = try requiredCacheContext()
        return try await store.fetchLocalIdentifiers(albumPhotoIDs: albumPhotoIDs)
    }

    func photo(id: UUID) async throws -> SharedPhotoDetail {
        do {
            return try Self.makePhoto(try await api.fetchPhoto(id: id))
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func comments(
        photoID: UUID,
        cursor: String?,
        size: Int
    ) async throws -> SharedPhotoCommentPage {
        do {
            let page = try await api.fetchComments(photoID: photoID, cursor: cursor, size: size)
            return SharedPhotoCommentPage(
                items: try page.items.map { try Self.makeComment($0, photoID: photoID) },
                nextCursor: page.nextCursor,
                hasNext: page.hasNext
            )
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func createComment(
        photoID: UUID,
        content: String,
        idempotencyKey: UUID
    ) async throws -> SharedPhotoComment {
        do {
            let response = try await api.createComment(
                photoID: photoID,
                content: content,
                idempotencyKey: idempotencyKey
            )
            return try Self.makeComment(response)
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    func setLike(photoID: UUID, isLiked: Bool) async throws -> SharedPhotoLikeState {
        do {
            let response: SharedPhotoLikeResponse
            if isLiked {
                response = try await api.likePhoto(id: photoID)
            } else {
                response = try await api.unlikePhoto(id: photoID)
            }
            return SharedPhotoLikeState(
                photoID: response.photoId,
                isLikedByMe: response.isLikedByMe,
                likeCount: response.likeCount
            )
        } catch let error as NetworkError where error.serverCode == "PHOTO_NOT_FOUND" {
            throw SharedPhotoRepositoryError.photoNotFound
        }
    }

    private func uploadBatches(
        localIdentifiers: [String],
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        context: CacheContext
    ) async throws -> UploadBatchOutcome {
        let batches = localIdentifiers.chunked(maxCount: 20)
        var outcomes: [UploadBatchOutcome] = []
        var index = 0
        while index < batches.count {
            if index + 1 < batches.count {
                let firstBatch = batches[index]
                let secondBatch = batches[index + 1]
                async let first = uploadBatchResult(
                    localIdentifiers: firstBatch,
                    groupID: groupID,
                    albumID: albumID,
                    context: context
                )
                async let second = uploadBatchResult(
                    localIdentifiers: secondBatch,
                    groupID: groupID,
                    albumID: albumID,
                    context: context
                )
                let pair = try await(first, second)
                outcomes.append(contentsOf: [pair.0, pair.1])
                index += 2
            } else {
                outcomes.append(try await uploadBatchResult(
                    localIdentifiers: batches[index],
                    groupID: groupID,
                    albumID: albumID,
                    context: context
                ))
                index += 1
            }
        }

        return UploadBatchOutcome(
            photoIDs: outcomes.flatMap(\.photoIDs),
            localIdentifiers: outcomes.flatMap(\.localIdentifiers),
            succeededCount: outcomes.reduce(0) { $0 + $1.succeededCount },
            failedCount: outcomes.reduce(0) { $0 + $1.failedCount }
        )
    }

    private func uploadBatchResult(
        localIdentifiers: [String],
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        context: CacheContext
    ) async throws -> UploadBatchOutcome {
        do {
            return try await uploadBatch(
                localIdentifiers: localIdentifiers,
                groupID: groupID,
                albumID: albumID,
                context: context
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return UploadBatchOutcome(
                photoIDs: [],
                localIdentifiers: [],
                succeededCount: 0,
                failedCount: localIdentifiers.count
            )
        }
    }

    private func uploadBatch(
        localIdentifiers: [String],
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        context: CacheContext
    ) async throws -> UploadBatchOutcome {
        var preparedAssets: [PreparedSharedPhotoAsset] = []
        var preparationFailureCount = 0
        for localIdentifier in localIdentifiers {
            do {
                var preparedAsset = try await assetPreparer.prepare(localIdentifier: localIdentifier)
                if preparedAsset.latitude != nil,
                   preparedAsset.longitude != nil,
                   let placeName = try? await store.fetchPlaceName(localIdentifier: localIdentifier),
                   !placeName.isEmpty {
                    preparedAsset = preparedAsset.withLocationName(placeName)
                }
                preparedAssets.append(preparedAsset)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                preparationFailureCount += 1
            }
        }
        defer {
            for asset in preparedAssets {
                assetPreparer.removePreparedFile(asset)
            }
        }
        guard !preparedAssets.isEmpty else {
            return UploadBatchOutcome(
                photoIDs: [],
                localIdentifiers: [],
                succeededCount: 0,
                failedCount: preparationFailureCount
            )
        }

        let batchID = UUID()
        let uploadedPhotoIDs: [UUID]
        do {
            uploadedPhotoIDs = try await reserveUploadAndComplete(
                preparedAssets: preparedAssets,
                groupID: groupID,
                albumID: albumID,
                batchID: batchID,
                context: context
            )
        } catch SharedPhotoRepositoryError.uploadURLExpired {
            uploadedPhotoIDs = try await reserveUploadAndComplete(
                preparedAssets: preparedAssets,
                groupID: groupID,
                albumID: albumID,
                batchID: batchID,
                context: context
            )
        } catch let error as NetworkError where error.serverCode == "UPLOAD_OBJECT_NOT_FOUND" {
            uploadedPhotoIDs = try await reserveUploadAndComplete(
                preparedAssets: preparedAssets,
                groupID: groupID,
                albumID: albumID,
                batchID: batchID,
                context: context
            )
        }

        return UploadBatchOutcome(
            photoIDs: uploadedPhotoIDs,
            localIdentifiers: preparedAssets.map(\.localIdentifier),
            succeededCount: uploadedPhotoIDs.count,
            failedCount: preparationFailureCount
        )
    }

    private func reserveUploadAndComplete(
        preparedAssets: [PreparedSharedPhotoAsset],
        groupID: ShareAlbum.ID,
        albumID: SharedAlbum.ID,
        batchID: UUID,
        context: CacheContext
    ) async throws -> [UUID] {
        let requestFiles = preparedAssets.map {
            SharedPhotoUploadFileRequest(contentType: $0.contentType, sizeBytes: $0.sizeBytes)
        }
        let reservation = try await retrying {
            try await api.issueUploadURLs(sharedAlbumID: albumID, files: requestFiles)
        }
        try validate(context)
        guard reservation.uploads.count == preparedAssets.count else {
            throw SharedPhotoRepositoryError.invalidServerResponse
        }

        let completionIdempotencyKey = UUID()
        var taskInputs: [SharedPhotoUploadTaskInput] = []
        for (asset, upload) in zip(preparedAssets, reservation.uploads) {
            guard let localPhotoID = try await store.fetchLocalPhotoID(localIdentifier: asset.localIdentifier),
                  let expiresAt = Self.date(upload.uploadUrlExpiresAt)
            else {
                throw SharedPhotoRepositoryError.invalidServerResponse
            }
            taskInputs.append(SharedPhotoUploadTaskInput(
                id: UUID(),
                sharedGroupID: groupID,
                sharedAlbumID: albumID,
                localPhotoID: localPhotoID,
                objectKey: upload.objectKey,
                uploadURL: upload.uploadUrl,
                uploadURLExpiresAt: expiresAt,
                contentType: upload.contentType,
                sizeBytes: asset.sizeBytes,
                idempotencyKey: completionIdempotencyKey,
                status: .reserved,
                createdAt: .now
            ))
        }
        try await store.replaceUploadTasks(
            batchID: batchID,
            with: taskInputs,
            cacheOwnerID: context.ownerID
        )

        try await uploadReservedFiles(
            preparedAssets: preparedAssets,
            uploads: reservation.uploads,
            taskInputs: taskInputs,
            context: context
        )

        let completionFiles = zip(preparedAssets, reservation.uploads).map { asset, upload in
            SharedPhotoUploadCompletionFileRequest(
                objectKey: upload.objectKey,
                deviceModel: asset.deviceModel,
                takenAt: asset.takenAt.map(Self.iso8601),
                latitude: asset.locationName == nil ? nil : asset.latitude,
                longitude: asset.locationName == nil ? nil : asset.longitude,
                locationName: asset.locationName,
                isInferred: asset.locationName == nil ? nil : asset.isInferred,
                width: asset.width,
                height: asset.height
            )
        }
        for task in taskInputs {
            try await store.updateUploadTaskStatus(
                id: task.id,
                status: .completing,
                cacheOwnerID: context.ownerID
            )
        }
        let completion = try await retrying {
            try await api.completeUpload(
                sharedAlbumID: albumID,
                files: completionFiles,
                idempotencyKey: completionIdempotencyKey
            )
        }
        try validate(context)
        guard completion.items.count == preparedAssets.count else {
            throw SharedPhotoRepositoryError.invalidServerResponse
        }

        let inputs = try zip(completion.items, taskInputs).map { item, task in
            try Self.makeStoreInput(item, localPhotoID: task.localPhotoID)
        }
        try await store.upsertPhotos(inputs, albumID: albumID, cacheOwnerID: context.ownerID)
        try await store.deleteUploadTasks(batchID: batchID, cacheOwnerID: context.ownerID)
        return completion.items.map(\.id)
    }

    private func uploadReservedFiles(
        preparedAssets: [PreparedSharedPhotoAsset],
        uploads: [SharedPhotoUploadURLResponse],
        taskInputs: [SharedPhotoUploadTaskInput],
        context: CacheContext
    ) async throws {
        let indices = Array(preparedAssets.indices)
        for chunk in indices.chunked(maxCount: 3) {
            switch chunk.count {
            case 3:
                async let first: Void = uploadReservedFile(
                    asset: preparedAssets[chunk[0]],
                    upload: uploads[chunk[0]],
                    task: taskInputs[chunk[0]],
                    context: context
                )
                async let second: Void = uploadReservedFile(
                    asset: preparedAssets[chunk[1]],
                    upload: uploads[chunk[1]],
                    task: taskInputs[chunk[1]],
                    context: context
                )
                async let third: Void = uploadReservedFile(
                    asset: preparedAssets[chunk[2]],
                    upload: uploads[chunk[2]],
                    task: taskInputs[chunk[2]],
                    context: context
                )
                _ = try await(first, second, third)
            case 2:
                async let first: Void = uploadReservedFile(
                    asset: preparedAssets[chunk[0]],
                    upload: uploads[chunk[0]],
                    task: taskInputs[chunk[0]],
                    context: context
                )
                async let second: Void = uploadReservedFile(
                    asset: preparedAssets[chunk[1]],
                    upload: uploads[chunk[1]],
                    task: taskInputs[chunk[1]],
                    context: context
                )
                _ = try await(first, second)
            case 1:
                try await uploadReservedFile(
                    asset: preparedAssets[chunk[0]],
                    upload: uploads[chunk[0]],
                    task: taskInputs[chunk[0]],
                    context: context
                )
            default:
                break
            }
        }
    }

    private func uploadReservedFile(
        asset: PreparedSharedPhotoAsset,
        upload: SharedPhotoUploadURLResponse,
        task: SharedPhotoUploadTaskInput,
        context: CacheContext
    ) async throws {
        guard let signedURL = URL(string: upload.uploadUrl),
              let expiresAt = Self.date(upload.uploadUrlExpiresAt)
        else {
            throw SharedPhotoRepositoryError.invalidSignedURL
        }
        guard expiresAt > .now else {
            throw SharedPhotoRepositoryError.uploadURLExpired
        }
        try await store.updateUploadTaskStatus(
            id: task.id,
            status: .uploading,
            cacheOwnerID: context.ownerID
        )
        do {
            do {
                try await objectStorage.upload(
                    fileURL: asset.fileURL,
                    to: signedURL,
                    contentType: upload.contentType,
                    contentLength: asset.sizeBytes
                )
            } catch ObjectStorageTransferError.unexpectedStatusCode(401),
                ObjectStorageTransferError.unexpectedStatusCode(403) {
                throw SharedPhotoRepositoryError.uploadURLExpired
            } catch {
                guard expiresAt > .now else {
                    throw SharedPhotoRepositoryError.uploadURLExpired
                }
                try await objectStorage.upload(
                    fileURL: asset.fileURL,
                    to: signedURL,
                    contentType: upload.contentType,
                    contentLength: asset.sizeBytes
                )
            }
        } catch ObjectStorageTransferError.unexpectedStatusCode(401),
            ObjectStorageTransferError.unexpectedStatusCode(403) {
            throw SharedPhotoRepositoryError.uploadURLExpired
        } catch {
            if expiresAt <= .now {
                throw SharedPhotoRepositoryError.uploadURLExpired
            }
            throw error
        }
        try validate(context)
        try await store.updateUploadTaskStatus(
            id: task.id,
            status: .uploaded,
            cacheOwnerID: context.ownerID
        )
    }

    private func attach(
        photoIDs: [UUID],
        to albumID: UUID,
        context: CacheContext
    ) async throws -> AttachmentOutcome {
        var succeededPhotoIDs: [UUID] = []
        var failedPhotoIDs: [UUID] = []
        for chunk in Self.unique(photoIDs).chunked(maxCount: 100) {
            let idempotencyKey = UUID()
            do {
                _ = try await retrying {
                    try await api.attachPhotos(
                        sharedAlbumID: albumID,
                        photoIDs: chunk,
                        idempotencyKey: idempotencyKey
                    )
                }
                try validate(context)
                try await store.addMemberships(
                    photoIDs: chunk,
                    to: albumID,
                    cacheOwnerID: context.ownerID
                )
                succeededPhotoIDs.append(contentsOf: chunk)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedPhotoIDs.append(contentsOf: chunk)
            }
        }
        return AttachmentOutcome(
            succeededPhotoIDs: succeededPhotoIDs,
            failedPhotoIDs: failedPhotoIDs
        )
    }

    private func refreshMutationState(
        groupID: ShareAlbum.ID,
        affectedAlbumIDs: [SharedAlbum.ID],
        context: CacheContext
    ) async {
        guard let groupAPI, let groupStore else { return }

        do {
            var cursor: String?
            var requestedCursors: Set<String> = []
            repeat {
                if let cursor, !requestedCursors.insert(cursor).inserted {
                    throw SharedPhotoRepositoryError.invalidPagination
                }
                let page = try await groupAPI.fetchSharedAlbums(
                    groupID: groupID,
                    cursor: cursor,
                    size: 100
                )
                try validate(context)
                try await groupStore.upsertSharedAlbums(
                    page.items,
                    groupID: groupID,
                    cacheOwnerID: context.ownerID
                )
                if page.hasNext {
                    guard let nextCursor = page.nextCursor, nextCursor != cursor else {
                        throw SharedPhotoRepositoryError.invalidPagination
                    }
                    cursor = nextCursor
                } else {
                    cursor = nil
                }
            } while cursor != nil

            let detail = try await groupAPI.fetchGroup(id: groupID)
            try validate(context)
            try await groupStore.upsertGroupDetail(detail, cacheOwnerID: context.ownerID)
        } catch {
            // 서버 사진 작업은 이미 성공했다. 메타데이터는 다음 새로고침에서 복구한다.
        }

        for albumID in Self.unique(affectedAlbumIDs) {
            do {
                _ = try await synchronizePhotos(in: albumID)
            } catch {
                // 다른 공유집의 동기화는 계속하고, 성공한 서버 작업은 유지한다.
            }
        }
    }

    private func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await operation()
        }
    }

    private func requiredCacheContext() throws -> CacheContext {
        guard let cacheOwnerID else {
            throw SharedPhotoRepositoryError.cacheNotPrepared
        }
        return CacheContext(ownerID: cacheOwnerID, sessionID: cacheSessionID)
    }

    private func validate(_ context: CacheContext) throws {
        guard cacheOwnerID == context.ownerID, cacheSessionID == context.sessionID else {
            throw CancellationError()
        }
    }

    private static func makeAlbumPhoto(_ stored: StoredSharedPhoto) -> SharedAlbumPhoto {
        SharedAlbumPhoto(
            id: stored.id,
            localIdentifier: stored.localIdentifier,
            originalURL: URL(string: stored.originalURL),
            originalURLExpiresAt: stored.originalURLExpiresAt,
            thumbnailURL: stored.thumbnailURL.flatMap(URL.init(string:)),
            thumbnailURLExpiresAt: stored.thumbnailURLExpiresAt,
            thumbnailStatus: SharedAlbumPhotoThumbnailStatus(serverValue: stored.thumbnailStatus),
            displayAt: stored.displayAt
        )
    }

    private static func makeStoreInput(
        _ response: SharedPhotoListItemResponse,
        localPhotoID: Int? = nil
    ) throws -> SharedPhotoStoreInput {
        guard let originalURLExpiresAt = date(response.originalUrlExpiresAt),
              let displayAt = date(response.displayAt),
              let createdAt = date(response.createdAt)
        else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoStoreInput(
            id: response.id,
            sharedGroupID: response.sharedGroupId,
            localPhotoID: localPhotoID,
            originalURL: response.originalUrl,
            originalURLExpiresAt: originalURLExpiresAt,
            thumbnailURL: response.thumbnailUrl,
            thumbnailURLExpiresAt: response.thumbnailUrlExpiresAt.flatMap(date),
            thumbnailStatus: response.thumbnailStatus,
            deviceModel: response.deviceModel,
            takenAt: response.takenAt.flatMap(date),
            displayAt: displayAt,
            latitude: response.latitude,
            longitude: response.longitude,
            locationName: response.locationName,
            isInferred: response.isInferred,
            width: response.width,
            height: response.height,
            uploadedByUserID: response.uploadedBy.userId,
            uploadedByDisplayName: response.uploadedBy.displayName,
            isUploader: response.isUploader,
            likeCount: response.likeCount,
            commentCount: response.commentCount,
            isLikedByMe: response.isLikedByMe,
            createdAt: createdAt,
            updatedAt: response.updatedAt.flatMap(date) ?? createdAt
        )
    }

    private static func makeStoreInput(
        _ response: SharedPhotoUploadItemResponse,
        localPhotoID: Int?
    ) throws -> SharedPhotoStoreInput {
        guard let originalURLExpiresAt = date(response.originalUrlExpiresAt),
              let createdAt = date(response.createdAt)
        else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        let takenAt = response.takenAt.flatMap(date)
        return SharedPhotoStoreInput(
            id: response.id,
            sharedGroupID: response.sharedGroupId,
            localPhotoID: localPhotoID,
            originalURL: response.originalUrl,
            originalURLExpiresAt: originalURLExpiresAt,
            thumbnailURL: response.thumbnailUrl,
            thumbnailURLExpiresAt: response.thumbnailUrlExpiresAt.flatMap(date),
            thumbnailStatus: response.thumbnailStatus,
            deviceModel: response.deviceModel,
            takenAt: takenAt,
            displayAt: takenAt ?? createdAt,
            latitude: response.latitude,
            longitude: response.longitude,
            locationName: response.locationName,
            isInferred: response.isInferred,
            width: response.width,
            height: response.height,
            uploadedByUserID: nil,
            uploadedByDisplayName: nil,
            isUploader: true,
            likeCount: 0,
            commentCount: 0,
            isLikedByMe: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private static func makeStoreInput(_ response: SharedPhotoDetailResponse) throws -> SharedPhotoStoreInput {
        guard let originalURLExpiresAt = date(response.originalUrlExpiresAt),
              let displayAt = date(response.displayAt),
              let createdAt = date(response.createdAt),
              let updatedAt = date(response.updatedAt)
        else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoStoreInput(
            id: response.id,
            sharedGroupID: response.sharedGroupId,
            localPhotoID: nil,
            originalURL: response.originalUrl,
            originalURLExpiresAt: originalURLExpiresAt,
            thumbnailURL: response.thumbnailUrl,
            thumbnailURLExpiresAt: response.thumbnailUrlExpiresAt.flatMap(date),
            thumbnailStatus: response.thumbnailStatus,
            deviceModel: response.deviceModel,
            takenAt: response.takenAt.flatMap(date),
            displayAt: displayAt,
            latitude: response.latitude,
            longitude: response.longitude,
            locationName: response.locationName,
            isInferred: response.isInferred,
            width: response.width,
            height: response.height,
            uploadedByUserID: response.uploadedBy.userId,
            uploadedByDisplayName: response.uploadedBy.displayName,
            isUploader: response.isUploader,
            likeCount: response.likeCount,
            commentCount: response.commentCount,
            isLikedByMe: response.isLikedByMe,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func unique<Element: Hashable>(_ values: [Element]) -> [Element] {
        var seen: Set<Element> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func makePhoto(_ response: SharedPhotoDetailResponse) throws -> SharedPhotoDetail {
        guard let originalURLExpiresAt = date(response.originalUrlExpiresAt),
              let displayAt = date(response.displayAt),
              let createdAt = date(response.createdAt),
              let updatedAt = date(response.updatedAt)
        else {
            throw SharedPhotoRepositoryError.invalidDate
        }

        return SharedPhotoDetail(
            id: response.id,
            sharedGroupID: response.sharedGroupId,
            sharedAlbumIDs: response.sharedAlbumIds,
            originalURL: response.originalUrl,
            originalURLExpiresAt: originalURLExpiresAt,
            thumbnailURL: response.thumbnailUrl,
            thumbnailURLExpiresAt: response.thumbnailUrlExpiresAt.flatMap(date),
            thumbnailStatus: response.thumbnailStatus,
            deviceModel: response.deviceModel,
            takenAt: response.takenAt.flatMap(date),
            displayAt: displayAt,
            latitude: response.latitude,
            longitude: response.longitude,
            locationName: response.locationName,
            isInferred: response.isInferred,
            width: response.width,
            height: response.height,
            uploadedBy: makeAuthor(response.uploadedBy),
            isUploader: response.isUploader,
            likeCount: response.likeCount,
            commentCount: response.commentCount,
            isLikedByMe: response.isLikedByMe,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeComment(
        _ response: PhotoCommentListItemResponse,
        photoID: UUID
    ) throws -> SharedPhotoComment {
        guard let createdAt = date(response.createdAt), let updatedAt = date(response.updatedAt) else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoComment(
            id: response.id,
            photoID: photoID,
            content: response.content,
            author: makeAuthor(response.author),
            isAuthor: response.isAuthor,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeComment(_ response: PhotoCommentCreateResponse) throws -> SharedPhotoComment {
        guard let createdAt = date(response.createdAt), let updatedAt = date(response.updatedAt) else {
            throw SharedPhotoRepositoryError.invalidDate
        }
        return SharedPhotoComment(
            id: response.id,
            photoID: response.photoId,
            content: response.content,
            author: makeAuthor(response.author),
            isAuthor: true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeAuthor(_ response: SharedPhotoAuthorResponse) -> SharedPhotoAuthor {
        SharedPhotoAuthor(id: response.userId, displayName: response.displayName)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

extension Array {
    fileprivate func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0, !isEmpty else { return [] }
        return stride(from: 0, to: count, by: maxCount).map { index in
            Array(self[index ..< Swift.min(index + maxCount, count)])
        }
    }

    fileprivate func asyncCompactMap<Result>(
        _ transform: (Element) async throws -> Result?
    ) async rethrows -> [Result] {
        var results: [Result] = []
        for element in self {
            if let result = try await transform(element) {
                results.append(result)
            }
        }
        return results
    }
}
