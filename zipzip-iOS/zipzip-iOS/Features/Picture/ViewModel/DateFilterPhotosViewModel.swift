//
//  DateFilterPhotosViewModel.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/15/26.
//

import Foundation
import OSLog
import SQLiteData
import SwiftUI
import UIKit

@Observable
final class DateFilterPhotosViewModel {
    @ObservationIgnored
    @Dependency(\.photoSections) private var photoSections

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zipzip-iOS",
        category: "DateFilterPhotos"
    )

    private static let thumbnailSize = CGSize(width: 300, height: 300)
    private static let dayComponents: Set<Calendar.Component> = [.year, .month, .day]

    private(set) var availableDays: Set<DateComponents> = []
    private(set) var thumbnailImages: [String: UIImage] = [:]

    @ObservationIgnored private var photosByDay: [Date: [Photo]] = [:]
    @ObservationIgnored private var loadingThumbnailIdentifiers: Set<String> = []

    @discardableResult
    func load() async -> Bool {
        do {
            let library = try await photoSections.loadLibrary()
            let registeredIDs = try await photoSections.loadRegisteredDeviceIDs()
            let calendar = Calendar.current

            var grouped: [Date: [(takenAt: Date, photo: Photo)]] = [:]
            for item in library {
                guard let deviceID = item.deviceID, registeredIDs.contains(deviceID),
                      let takenAt = item.takenAt
                else {
                    continue
                }
                let day = calendar.startOfDay(for: takenAt)
                grouped[day, default: []].append((takenAt, item.photo))
            }

            photosByDay = grouped.mapValues { entries in
                entries.sorted { $0.takenAt > $1.takenAt }.map(\.photo)
            }
            availableDays = Set(grouped.keys.map { calendar.dateComponents(Self.dayComponents, from: $0) })
            return true
        } catch {
            Self.logger.error("failed to load date filter photos: \(error)")
            return false
        }
    }

    func photos(on date: Date?) -> [Photo] {
        guard let date else { return [] }
        let day = Calendar.current.startOfDay(for: date)
        return photosByDay[day] ?? []
    }

    func loadThumbnail(for localIdentifier: String) async {
        guard !localIdentifier.isEmpty,
              thumbnailImages[localIdentifier] == nil,
              !loadingThumbnailIdentifiers.contains(localIdentifier)
        else {
            return
        }

        loadingThumbnailIdentifiers.insert(localIdentifier)
        defer { loadingThumbnailIdentifiers.remove(localIdentifier) }

        let image = await PhotoThumbnailLoader.shared.thumbnail(
            for: localIdentifier,
            targetSize: Self.thumbnailSize
        )
        guard !Task.isCancelled, let image else { return }
        thumbnailImages[localIdentifier] = image
    }
}
