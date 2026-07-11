//
//  DeviceModelCatalog.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation

enum DeviceModelCatalog {
    static func filterDevice(make: String?, model: String?) -> FilterDevice {
        let make = make?.trimmingCharacters(in: .whitespaces)
        let model = model?.trimmingCharacters(in: .whitespaces)

        if make == "Apple", let identifier = model, !identifier.isEmpty {
            let name = appleModelNames[identifier] ?? identifier
            if identifier.hasPrefix("iPad") {
                return FilterDevice(name: name, type: "아이패드")
            }
            return FilterDevice(name: name, type: "아이폰")
        }

        let name = [make, model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return FilterDevice(name: name.isEmpty ? "알 수 없는 기기" : name, type: "디지털 카메라")
    }

    private static let appleModelNames: [String: String] = [
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2세대)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3세대)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus"
    ]
}
