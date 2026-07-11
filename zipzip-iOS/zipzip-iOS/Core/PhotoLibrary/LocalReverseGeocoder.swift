//
//  LocalReverseGeocoder.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import CoreLocation
import Foundation
import MapKit

nonisolated struct LocalReverseGeocoder {
    private let domestic: [GeoRegion]
    private let foreign: [GeoRegion]

    init() {
        self.domestic = Self.load("HangJeongDong", nameKey: "adm_nm")
        self.foreign = Self.load("Countries", nameKey: "NAME_KO")
    }

    var isEmpty: Bool {
        domestic.isEmpty && foreign.isEmpty
    }

    func label(latitude: Double, longitude: Double) -> String? {
        let point = MKMapPoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        if let admName = match(point, in: domestic) {
            return PlaceLabelCatalog.label(regionCode: "KR", regionName: nil, fullAddress: admName)
        }
        return match(point, in: foreign)
    }

    private func match(_ point: MKMapPoint, in regions: [GeoRegion]) -> String? {
        for region in regions where region.rect.contains(point) {
            for polygon in region.polygons where polygon.rect.contains(point) {
                if Self.contains(point, outer: polygon.outer, holes: polygon.holes) {
                    return region.name
                }
            }
        }
        return nil
    }

    private static func contains(_ point: MKMapPoint, outer: [MKMapPoint], holes: [[MKMapPoint]]) -> Bool {
        guard rayCast(point, ring: outer) else { return false }
        for hole in holes where rayCast(point, ring: hole) {
            return false
        }
        return true
    }

    private static func rayCast(_ point: MKMapPoint, ring: [MKMapPoint]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i]
            let b = ring[j]
            if (a.y > point.y) != (b.y > point.y) {
                let t = (point.y - a.y) / (b.y - a.y)
                if point.x < a.x + t * (b.x - a.x) {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    private static func load(_ resource: String, nameKey: String) -> [GeoRegion] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let objects = try? MKGeoJSONDecoder().decode(data)
        else { return [] }

        var regions: [GeoRegion] = []
        for case let feature as MKGeoJSONFeature in objects {
            guard let name = name(from: feature.properties, key: nameKey) else { continue }
            var polygons: [GeoPolygon] = []
            for shape in feature.geometry {
                if let polygon = shape as? MKPolygon {
                    polygons.append(geoPolygon(from: polygon))
                } else if let multiPolygon = shape as? MKMultiPolygon {
                    polygons.append(contentsOf: multiPolygon.polygons.map(geoPolygon))
                }
            }
            guard let first = polygons.first else { continue }
            let rect = polygons.dropFirst().reduce(first.rect) { $0.union($1.rect) }
            regions.append(GeoRegion(name: name, polygons: polygons, rect: rect))
        }
        return regions
    }

    private static func geoPolygon(from polygon: MKPolygon) -> GeoPolygon {
        GeoPolygon(
            outer: points(of: polygon),
            holes: (polygon.interiorPolygons ?? []).map(points(of:)),
            rect: polygon.boundingMapRect
        )
    }

    private static func points(of polygon: MKPolygon) -> [MKMapPoint] {
        Array(UnsafeBufferPointer(start: polygon.points(), count: polygon.pointCount))
    }

    private static func name(from properties: Data?, key: String) -> String? {
        guard let properties,
              let json = try? JSONSerialization.jsonObject(with: properties) as? [String: Any],
              let value = json[key] as? String,
              !value.isEmpty
        else { return nil }
        return value
    }
}

private struct GeoRegion {
    let name: String
    let polygons: [GeoPolygon]
    let rect: MKMapRect
}

private struct GeoPolygon {
    let outer: [MKMapPoint]
    let holes: [[MKMapPoint]]
    let rect: MKMapRect
}
