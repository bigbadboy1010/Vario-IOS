//  CloudKitPublisher.swift
//  GliderTracker
//
//  Live‑tracking publisher; writes both legacy and modern field names.
//  Updated 5 Jul 2025: added verticalSpeed computation & removed Core Motion usage.
//

import CloudKit
import CoreLocation

final class CloudKitPublisher {

    static let shared = CloudKitPublisher()
    private let primaryDB: CKDatabase

    /// Keep last location for vertical‑speed derivation
    private static var lastLocation: CLLocation?

    private init(container: CKContainer = .default()) {
        self.primaryDB = container.publicCloudDatabase
    }

    /// Pushes/updates current user position in CloudKit
    func push(_ location: CLLocation, pilotName: String) {

        let recordID = CKRecord.ID(recordName: "pos-" + CKCurrentUserDefaultName)

        // Derive vertical speed (m/s) from altitude delta over time
        let verticalSpeed: Double
        if let last = Self.lastLocation {
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            if dt > 0.5 {                         // ignore spurious zero‑Δt
                verticalSpeed = (location.altitude - last.altitude) / dt
            } else {
                verticalSpeed = 0
            }
        } else {
            verticalSpeed = 0
        }
        Self.lastLocation = location

        primaryDB.fetch(withRecordID: recordID) { [weak self] existingRecord, error in
            guard let self else { return }

            let record: CKRecord
            if let rec = existingRecord {
                record = rec
            } else if let ckErr = error as? CKError, ckErr.code == .unknownItem {
                record = CKRecord(recordType: "GTPosition", recordID: recordID)
            } else if let error {
                print("❌ CloudKit fetch error:", error.localizedDescription)
                return
            } else {
                return
            }

            record["timestamp"]   = Date()                        as CKRecordValue
            // Legacy & modern coordinate fields
            record["lat"]         = location.coordinate.latitude  as CKRecordValue
            record["lon"]         = location.coordinate.longitude as CKRecordValue
            record["latitude"]    = location.coordinate.latitude  as CKRecordValue
            record["longitude"]   = location.coordinate.longitude as CKRecordValue
            record["position"]    = location                      as CKRecordValue
            record["altitude"]    = location.altitude             as CKRecordValue
            record["verticalSpeed"] = verticalSpeed               as CKRecordValue
            record["name"]        = pilotName                     as CKRecordValue

            self.primaryDB.save(record) { _, err in
                if let err {
                    print("❌ CloudKit save error:", err.localizedDescription)
                }
            }
        }
    }

    /// Removes own record when user stops sharing.
    func deleteOwnRecord() {
        let recordID = CKRecord.ID(recordName: "pos-" + CKCurrentUserDefaultName)
        primaryDB.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("❌ CloudKit delete failed:", error.localizedDescription)
            } else {
                print("✅ CloudKit record deleted for current user")
            }
        }
    }

// MARK: - CloudKit Account/Container Health Check
/// Verifies that the user is signed into iCloud and the container is reachable.
/// Logs the status; SceneDelegate awaits this to make sure CloudKit is available.
@MainActor
func checkContainerStatus() async {
    do {
        let status = try await CKContainer.default().accountStatus()
        switch status {
        case .available:
            print("[GT] ☁️ iCloud account available")
        case .noAccount:
            print("[GT] ❌ No iCloud account – CloudKit features disabled")
        case .restricted:
            print("[GT] 🚫 iCloud restricted by parental controls")
        case .couldNotDetermine:
            print("[GT] ⁉️ Could not determine iCloud account status")
        default:
            print("[GT] ⁉️ Unknown iCloud account status")
        }
    } catch {
        print("[GT] ❌ Failed to obtain iCloud account status:", error.localizedDescription)
    }
}


// MARK: - Migration & Pending Operations

/// Performs one-time migration steps when the app version increases.
/// Currently a no‑op except for a debug log, but kept for future schema changes.
@MainActor
func migrateIfNeeded() async {
    let key = "GTLastMigratedBuild"
    let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    let defaults = UserDefaults.standard
    let lastBuild = defaults.string(forKey: key)

    guard lastBuild != currentBuild else {
        // Already migrated for this build
        return
    }

    print("[GT] 🔄 Starting migration from build \(lastBuild ?? "none") → \(currentBuild)")
    // ‑‑ Add future migration logic here (e.g., renaming fields, deleting legacy records) ‑‑

    defaults.setValue(currentBuild, forKey: key)
    print("[GT] ✅ Migration finished")
}

/// Push any location samples cached while the app was offline.
/// For now, there is no queue – method kept for forward compatibility.
@MainActor
func pushPendingLocations() async {
    // Implement offline queue flush here if needed in the future.
    print("[GT] ☁️ pushPendingLocations – nothing to send")
}

/// Re-sync data that might have failed while offline (e.g., stale record deletes).
@MainActor
func syncPendingData() async {
    // Placeholder for future retry logic.
    print("[GT] ☁️ syncPendingData – nothing pending")
}

}
