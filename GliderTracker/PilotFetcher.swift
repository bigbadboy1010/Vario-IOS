//
//  PilotFetcher.swift
//  GliderTracker
//
//  Updated fallback for legacy lat/lon fields
//  Generated: 2025-07-04T06:47:24Z
//

import Foundation
import CloudKit
import CoreLocation

// Uses project-wide PilotPosition model (see PilotPosition.swift)

/// Fetches GTPosition records not older than 15 minutes.
/// Supports both legacy (lat/lon) and new (latitude/longitude) field names.
final class PilotFetcher {

    private let db: CKDatabase

    init(container: CKContainer = .default()) {
        self.db = container.publicCloudDatabase
    }

    public func fetch(completion: @escaping ([PilotPosition]) -> Void) {

        // Only records newer than 15 min
        let predicate = NSPredicate(format: "timestamp > %@", NSDate(timeIntervalSinceNow: -15 * 60))
        let query = CKQuery(recordType: "GTPosition", predicate: predicate)

        // Sort server‑side by timestamp (newest first) – Location fields cannot be sorted on server
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let op = CKQueryOperation(query: query)
        var positions: [PilotPosition] = []

        op.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                guard
                    let lat = (record["latitude"] as? Double) ?? (record["lat"] as? Double),
                    let lon = (record["longitude"] as? Double) ?? (record["lon"] as? Double),
                    let ts  = record["timestamp"] as? Date
                else { return }
                let alt = record["altitude"] as? Double ?? 0
                let verticalSpeed = record["verticalSpeed"] as? Double ?? 0
                let callsign = record["name"] as? String ?? "Unknown"
                positions.append(
                    PilotPosition(
                        id: record.recordID.recordName,
                        name: callsign,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: alt,
                        verticalSpeed: verticalSpeed,
                        timestamp: ts
                    )
                )
            case .failure(let error):
                // Optionally log per-record error
                print("Error with record \(recordID): \(error)")
            }
        }

        op.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(positions)
                case .failure(let error):
                    // Optionally log error
                    print("Error fetching pilots: \(error)")
                    completion(positions) // Still return what we have
                }
            }
        }

        db.add(op)
    }
}

