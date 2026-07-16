//
//  PhotoSectionsProvider.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation
import SQLiteData

struct FilterablePhoto {
    let photo: Photo
    let deviceID: Int?
    let takenAt: Date?
    let addedAt: Date
    let addedDate: Date
    let hasLocation: Bool
}

nonisolated struct PhotoSectionsProvider {
    @Dependency(\.defaultDatabase) private var database

    func loadLibrary() async throws -> [FilterablePhoto] {
        try await database.read { db in
            let records = try PhotoRecord.all.fetchAll(db)
            let devices = try DeviceRecord.all.fetchAll(db)
            let places = try PlaceRecord.all.fetchAll(db)

            return Self.makeFilterablePhotos(records: records, devices: devices, places: places)
        }
    }

    /// 등록된 기기 id 집합. library와 함께 한 번 로드해 캐시하는 용도.
    func loadRegisteredDeviceIDs() async throws -> Set<Int> {
        try await database.read { db in
            let ids = try DeviceRecord
                .where { $0.isRegistered.eq(true) }
                .select(\.id)
                .fetchAll(db)
            return Set(ids)
        }
    }

    func sections(
        from library: [FilterablePhoto],
        filters: [AppliedFilter],
        registeredDeviceIDs: Set<Int>
    ) async -> [PhotoSection] {
        Self.registeredSections(from: library, filters: filters, registeredDeviceIDs: registeredDeviceIDs)
    }

    func loadAlbumSections(albumID: Int) async throws -> [PhotoSection] {
        let albumPhotos = try await database.read { db in
            let records = try PhotoRecord
                .join(AlbumPhotoRecord.all) { $0.id.eq($1.photoID) }
                .where { $1.albumID.eq(albumID) }
                .order { photo, albumPhoto in (albumPhoto.addedAt.desc(), photo.id.desc()) }
                .select { photo, albumPhoto in (photo, albumPhoto) }
                .fetchAll(db)
            let devices = try DeviceRecord.all.fetchAll(db)
            let places = try PlaceRecord.all.fetchAll(db)

            return Self.makeAlbumFilterablePhotos(records: records, devices: devices, places: places)
        }

        return await sections(from: albumPhotos, filters: [])
    }

    func sections(from library: [FilterablePhoto], filters: [AppliedFilter]) async -> [PhotoSection] {
        Self.makeSections(from: library, filters: filters)
    }

    /// 등록된 기기의 사진만 노출한 뒤 필터/그룹핑한다.
    static func registeredSections(
        from library: [FilterablePhoto],
        filters: [AppliedFilter],
        registeredDeviceIDs: Set<Int>
    ) -> [PhotoSection] {
        let registeredPhotos = library.filter { photo in
            guard let deviceID = photo.deviceID else { return false }
            return registeredDeviceIDs.contains(deviceID)
        }
        return makeSections(from: registeredPhotos, filters: filters)
    }

    static func makeSections(
        from photos: [FilterablePhoto],
        filters: [AppliedFilter]
    ) -> [PhotoSection] {
        var filtered = photos
        // 같은 종류(kind) 내에서는 OR(합집합), 종류 간에는 AND(교집합)로 적용한다.
        let grouped = Dictionary(grouping: filters, by: \.kind)
        for kind in [FilterKind.device, .location, .date, .etc] {
            guard let kindFilters = grouped[kind], !kindFilters.isEmpty else { continue }
            if kindFilters.count == 1 {
                filtered = apply(kindFilters[0], to: filtered)
            } else {
                var union: [FilterablePhoto] = []
                var seen = Set<String>()
                for filter in kindFilters {
                    for photo in apply(filter, to: filtered)
                        where seen.insert(photo.photo.localIdentifier).inserted {
                        union.append(photo)
                    }
                }
                filtered = union
            }
        }

        let sorted = filtered.sorted { lhs, rhs in
            switch (lhs.takenAt, rhs.takenAt) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.addedAt > rhs.addedAt
            }
        }

        let items = sorted.map { (date: $0.takenAt, photo: $0.photo) }
        return PhotoSectionGrouping.sections(from: items)
    }

    private static let recentPhotoLimit = 50

    static func makeFilterablePhotos(
        records: [PhotoRecord],
        devices: [DeviceRecord],
        places: [PlaceRecord]
    ) -> [FilterablePhoto] {
        let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        let placeByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

        return records.map {
            makeFilterablePhoto(
                record: $0,
                deviceByID: deviceByID,
                placeByID: placeByID
            )
        }
    }

    private static func makeAlbumFilterablePhotos(
        records: [(PhotoRecord, AlbumPhotoRecord)],
        devices: [DeviceRecord],
        places: [PlaceRecord]
    ) -> [FilterablePhoto] {
        let deviceByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        let placeByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

        return records.map { photo, albumPhoto in
            makeFilterablePhoto(
                record: photo,
                deviceByID: deviceByID,
                placeByID: placeByID,
                albumPhotoID: albumPhoto.id,
                addedAt: albumPhoto.addedAt
            )
        }
    }

    private static func makeFilterablePhoto(
        record: PhotoRecord,
        deviceByID: [Int: DeviceRecord],
        placeByID: [Int: PlaceRecord],
        albumPhotoID: Int? = nil,
        addedAt: Date? = nil
    ) -> FilterablePhoto {
        let device = record.deviceID.flatMap { deviceByID[$0] }
        let filterDevice = DeviceModelCatalog.filterDevice(make: device?.make, model: device?.model)
        let place = record.placeID.flatMap { placeByID[$0] }
        let dateText = record.takenAt.map(AppliedFilter.dateText) ?? ""
        let metadata = PhotoMetadata(
            deviceName: filterDevice.name,
            deviceType: filterDevice.type,
            location: place?.name ?? "",
            dateText: dateText
        )
        return FilterablePhoto(
            photo: Photo(
                localIdentifier: record.localIdentifier,
                metadata: metadata,
                albumPhotoID: albumPhotoID
            ),
            deviceID: record.deviceID,
            takenAt: record.takenAt,
            addedAt: addedAt ?? record.addedAt,
            addedDate: record.addedDate,
            hasLocation: record.placeID != nil
        )
    }

    private static func apply(_ filter: AppliedFilter, to photos: [FilterablePhoto]) -> [FilterablePhoto] {
        switch filter.kind {
        case .device:
            return photos.filter { $0.photo.metadata.deviceName == filter.value }
        case .date:
            guard let target = AppliedFilter.date(from: filter.value) else { return photos }
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: target)
            return photos.filter { photo in
                guard let taken = photo.takenAt else { return false }
                return calendar.startOfDay(for: taken) == day
            }
        case .location:
            return photos.filter { $0.photo.metadata.location == filter.value }
        case .etc:
            switch filter.value {
            case PhotoFilterOptions.EtcItem.noLocation:
                return photos.filter { !$0.hasLocation }
            case PhotoFilterOptions.EtcItem.noDate:
                return photos.filter { $0.takenAt == nil }
            case PhotoFilterOptions.EtcItem.recentlyAdded:
                return photos
                    .sorted { $0.addedDate > $1.addedDate }
                    .prefix(recentPhotoLimit)
                    .map { $0 }
            default:
                return photos
            }
        }
    }
}

/// 등록된 기기의 사진 섹션을 DB 관찰로 제공한다.
/// `device.is_registered`/`photo`/`place` 변경 시 자동으로 재실행돼 사진 뷰가 갱신된다.
nonisolated struct PhotoSectionsRequest: FetchKeyRequest {
    let filters: [AppliedFilter]

    init(filters: [AppliedFilter] = []) {
        self.filters = filters
    }

    func fetch(_ db: Database) throws -> [PhotoSection] {
        let records = try PhotoRecord.all.fetchAll(db)
        let devices = try DeviceRecord.all.fetchAll(db)
        let places = try PlaceRecord.all.fetchAll(db)

        let registeredDeviceIDs = Set(devices.filter(\.isRegistered).map(\.id))
        let library = PhotoSectionsProvider.makeFilterablePhotos(records: records, devices: devices, places: places)
        return PhotoSectionsProvider.registeredSections(
            from: library,
            filters: filters,
            registeredDeviceIDs: registeredDeviceIDs
        )
    }
}

/// 등록된 기기에 귀속된 사진 수를 DB 관찰로 제공한다.
/// `device.is_registered`/`photo.device_id` 변경 시 자동으로 재실행돼 실시간 갱신된다.
nonisolated struct RegisteredPhotoCountRequest: FetchKeyRequest {
    func fetch(_ db: Database) throws -> Int {
        try PhotoRecord
            .join(DeviceRecord.all) { photo, device in photo.deviceID.eq(device.id) }
            .where { _, device in device.isRegistered.eq(true) }
            .select { photo, _ in photo.id.count() }
            .fetchOne(db) ?? 0
    }
}

private enum PhotoSectionsProviderKey: DependencyKey {
    static let liveValue = PhotoSectionsProvider()
}

extension DependencyValues {
    var photoSections: PhotoSectionsProvider {
        get { self[PhotoSectionsProviderKey.self] }
        set { self[PhotoSectionsProviderKey.self] = newValue }
    }
}
