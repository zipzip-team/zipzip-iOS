//
//  DetectedDevice.swift
//  zipzip-iOS
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct DetectedDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let modelName: String
    let type: DeviceType

    init(
        id: String? = nil,
        name: String,
        modelName: String,
        type: DeviceType
    ) {
        self.id = id ?? "\(type)-\(name)-\(modelName)"
        self.name = name
        self.modelName = modelName
        self.type = type
    }
}

enum DeviceType: Hashable {
    case camera
    case phone

    var icon: ImageResource {
        switch self {
        case .camera: .camera
        case .phone: .iphone
        }
    }

    var iconSize: CGSize {
        switch self {
        case .camera: CGSize(width: 34, height: 34)
        case .phone: CGSize(width: 36, height: 36)
        }
    }
}

extension DetectedDevice {
    static let samples: [DetectedDevice] = [
        DetectedDevice(
            name: "캐논 디지털 카메라",
            modelName: "Canon IXUS 860",
            type: .camera
        ),
        DetectedDevice(
            name: "아이폰",
            modelName: "iphone 6",
            type: .phone
        ),
        DetectedDevice(
            name: "아이폰",
            modelName: "iphone 6s",
            type: .phone
        )
    ]
}
