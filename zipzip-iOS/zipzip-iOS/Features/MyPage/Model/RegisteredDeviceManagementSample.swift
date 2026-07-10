//
//  RegisteredDeviceManagementSample.swift
//  zipzip-iOS
//
//  Created by Codex on 7/9/26.
//

extension DetectedDevice {
    static let registeredDeviceSamples: [DetectedDevice] = [
        .init(name: "캐논 디지털 카메라", modelName: "Canon IXUS 860", type: .camera),
        .init(name: "아이폰", modelName: "iphone 6s", type: .phone),
        .init(name: "아이폰", modelName: "iphone 6", type: .phone)
    ]

    static let registerableDeviceSamples: [DetectedDevice] = [
        .init(name: "소니 디지털 카메라", modelName: "소니 A6000", type: .camera),
        .init(name: "캐논 디지털 카메라", modelName: "Canon EOS R50", type: .camera),
        .init(name: "아이폰", modelName: "iphone XS", type: .phone),
        .init(name: "아이폰", modelName: "iphone 7", type: .phone)
    ]
}
