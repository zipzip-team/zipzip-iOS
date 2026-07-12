//
//  DeviceModelCatalog.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import Foundation

enum DeviceCategory {
    case iPhone
    case iPad
    case galaxy
    case camera
    case unknown

    var typeLabel: String {
        switch self {
        case .iPhone: "아이폰"
        case .iPad: "아이패드"
        case .galaxy: "갤럭시"
        case .camera: "디지털 카메라"
        case .unknown: "알 수 없는 기기"
        }
    }
}

nonisolated enum DeviceModelCatalog {
    static func category(make: String?, model: String?) -> DeviceCategory {
        let make = normalized(make)
        let model = normalized(model)

        if make == "apple" || model.hasPrefix("iphone") || model.hasPrefix("ipad") {
            return model.hasPrefix("ipad") ? .iPad : .iPhone
        }

        if isAndroidPhone(make: make, model: model) {
            return .galaxy
        }

        if isCameraBrand(make: make) {
            return .camera
        }

        return .unknown
    }

    static func filterDevice(make: String?, model: String?) -> FilterDevice {
        let rawMake = make?.trimmingCharacters(in: .whitespaces)
        let rawModel = model?.trimmingCharacters(in: .whitespaces)
        let category = category(make: make, model: model)

        switch category {
        case .iPhone, .iPad:
            let name = rawModel ?? ""
            return FilterDevice(
                name: name.isEmpty ? category.typeLabel : name,
                type: category.typeLabel
            )
        case .galaxy, .camera, .unknown:
            let name = displayName(make: rawMake, model: rawModel)
            return FilterDevice(
                name: name.isEmpty ? category.typeLabel : name,
                type: category.typeLabel
            )
        }
    }

    // MARK: - Classification

    private static func isAndroidPhone(make: String, model: String) -> Bool {
        if catalog.androidPhones.modelPrefixes.contains(where: { model.hasPrefix($0.lowercased()) }) {
            return true
        }
        // 삼성처럼 카메라 브랜드이면서 스마트폰 제조사인 경우, 제조사명만으로는 갤럭시로 단정하지
        // 않는다(카메라 모델은 위 modelPrefixes에 걸리지 않으므로 아래 카메라 분류로 넘어간다).
        if catalog.androidPhones.makeKeywords.contains(where: { make.contains($0) }),
           !isCameraBrand(make: make) {
            return true
        }
        return false
    }

    private static func isCameraBrand(make: String) -> Bool {
        guard !make.isEmpty else { return false }
        return catalog.cameraBrands.contains { make.contains($0) }
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func displayName(make: String?, model: String?) -> String {
        [make, model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Catalog Resource

    private struct Catalog: Decodable {
        let androidPhones: AndroidPhones
        let cameraBrands: [String]

        struct AndroidPhones: Decodable {
            let makeKeywords: [String]
            let modelPrefixes: [String]
        }

        static let empty = Catalog(
            androidPhones: AndroidPhones(makeKeywords: [], modelPrefixes: []),
            cameraBrands: []
        )
    }

    private static let catalog: Catalog = {
        guard let url = Bundle.main.url(forResource: "DeviceCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data)
        else { return .empty }
        return catalog
    }()
}
