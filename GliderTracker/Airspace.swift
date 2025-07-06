//
//  Airspace.swift
//  GliderTracker
//
//  1 struct  –  2 Hilfs-Typen
//  ---------------------------------------------
//  • Airspace.Coordinate  – ein Eckpunkt (lat, lon)
//  • Airspace.Altitude    – optional min / max
//  • Airspace             – Zone mit Punkte-Array
//

import Foundation
import CoreLocation
import MapKit

/// JSON-Schema:
/// { "id": "...", "name": "...", "category": "...",
///   "points": [ { "lat": 47.5, "lon": 9.7 }, … ],
///   "floor": { "value": 2500, "unit": "ft" },
///   "ceiling": { "value": 4500, "unit": "ft" } }
struct Airspace: Decodable, Equatable {
    struct Coordinate: Decodable, Equatable {
        let lat: Double
        let lon: Double

        var clLocation: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    struct Altitude: Decodable, Equatable {
        let value: Double
        let unit: String      // "ft", "m", "FL" …
    }

    let id: String
    let name: String
    let category: String

    let points: [Coordinate]
    let floor: Altitude?
    let ceiling: Altitude?

    // MARK: - Helpers

    /// MKPolygon zur Kartendarstellung
    var polygon: MKPolygon {
        let coords = points.map(\.clLocation)
        return MKPolygon(coordinates: coords, count: coords.count)
    }

    /// Prüft via Ray-Casting, ob Location in Polygon liegt
    func contains(location: CLLocation) -> Bool {
        guard points.count > 2 else { return false }

        let test = location.coordinate
        var j = points.count - 1
        var inside = false

        for i in 0..<points.count {
            let xi = points[i].lat, yi = points[i].lon
            let xj = points[j].lat, yj = points[j].lon
            if ((yi > test.longitude) != (yj > test.longitude)) &&
                (test.latitude < (xj - xi) * (test.longitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}


extension Airspace.Altitude {
    /// Convenience initializer to create altitude from a plain integer value
    /// (interpreted as feet, matching OpenAIP’s default unit).
    init(_ intValue: Int) {
        self.init(value: Double(intValue), unit: "ft")
    }
}
