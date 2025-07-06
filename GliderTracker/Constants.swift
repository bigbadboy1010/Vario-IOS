//
//  Constants.swift
//  GliderTracker – unified constants
//
//  Updated for Multi-Container CloudKit Support + Pilot Names - 2025-06-12
//

import Foundation

// MARK: – Base constants
struct Constants {
    /// Legacy CloudKit‑Container‑Identifier (backwards compatibility)
    @available(*, deprecated, message: "Use AppConstants.legacyiCloudContainerID instead")
    static let iCloudContainerID = "iCloud.com.miggu69.glidertracker"
    
    /// Primary CloudKit‑Container‑Identifier (new)
    static let primaryiCloudContainerID = "iCloud.org.miggu69.GliderTracker"
    
    /// Legacy CloudKit‑Container‑Identifier (migration)
    static let legacyiCloudContainerID = "iCloud.com.miggu69.glidertracker"
}

// MARK: – Convenience TimeZone
extension TimeZone {
    /// Koordinierte Weltzeit (UTC)
    public static let utc = TimeZone(secondsFromGMT: 0)!
}

// MARK: – Application‑wide constants
struct AppConstants {

    // MARK: - iCloud Container Configuration
    
    /// Primary iCloud container (new) - verwendet für neue Daten
    static let primaryiCloudContainerID = Constants.primaryiCloudContainerID
    
    /// Legacy iCloud container (old) - verwendet für Migration
    static let legacyiCloudContainerID = Constants.legacyiCloudContainerID
    
    /// Backwards compatibility - zeigt auf Primary Container
    @available(*, deprecated, message: "Use primaryiCloudContainerID instead")
    static let iCloudContainerID = primaryiCloudContainerID

    // MARK: - CloudKit Configuration
    
    /// CloudKit Record Types
    struct RecordTypes {
        static let position = "GTPosition"
        static let flight = "GTFlight"
        static let airspace = "GTAirspace"
    }
    
    /// CloudKit Field Names
    struct FieldNames {
        static let timestamp = "timestamp"
        static let latitude = "lat"
        static let longitude = "lon"
        static let altitude = "altitude"
        static let userId = "userId"
        static let flightId = "flightId"
        static let name = "name"  // 🆕 Added pilot name field
    }
    
    /// CloudKit Zones
    struct Zones {
        static let defaultZone = "_defaultZone"
        static let sharedZone = "_sharedZone"
    }

    // MARK: - Migration & Sync
    
    /// UserDefaults Keys für CloudKit
    struct UserDefaultsKeys {
        static let migrationCompleted = "CloudKitMigrationCompleted"
        static let lastSyncDate = "LastCloudKitSyncDate"
        static let lastMigrationDate = "LastMigrationDate"
        static let primaryContainerFirstUse = "PrimaryContainerFirstUse"
        
        // Audio Settings
        static let climbSensitivity = "climbSensitivity"
        static let sinkSensitivity = "sinkSensitivity"
        
        // Flight Settings
        static let autoStartRecording = "autoStartRecording"
        static let backgroundLocationEnabled = "backgroundLocationEnabled"
        
        // 🆕 Pilot & Emergency Settings
        static let pilotName = "pilotName"
        static let sharePosition = "sharePosition"
        static let emergencyEnabled = "emergencyEnabled"
        static let emergencyContact = "emergencyContact"
        static let emergencyPhone = "emergencyPhone"
    }

    // MARK: - Luftraum‑Konfiguration
    struct Airspace {
        /// Automatisches Update‑Intervall (24 h)
        static let updateInterval: TimeInterval = 24 * 60 * 60
        
        /// OpenAIP API Konfiguration
        static let apiBaseURL = "https://api.core.openaip.net/api"
        static let apiKey = "c00232952896543cc6d56e349b1f9cef"
        
        /// Default Radius für Luftraum-Abfragen (km)
        static let defaultRadius: Double = 100.0
        
        /// Minimum Abstand für neue Luftraum-Abfragen (m)
        static let minimumDistanceForUpdate: Double = 5000.0
    }

    // MARK: - Audio Configuration
    struct Audio {
        static let sampleRate: Double = 44_100.0
        static let defaultClimbFrequency: Double = 600.0
        static let maxClimbFrequency: Double = 1_200.0
        static let minSinkFrequency: Double = 150.0
        
        /// Debounce-Zeit zwischen Audio-Signalen
        static let debounceInterval: TimeInterval = 0.20
        
        /// Standard Audio-Kategorien
        static let category = "playback"
        static let options = ["mixWithOthers", "duckOthers"]
    }
    
    // MARK: - Location Configuration - 🔧 FIXED: Weniger aggressiv für ruhigere Karte
    struct Location {
        static let defaultAccuracy: Double = 10.0  // meters
        static let backgroundLocationTimeout: TimeInterval = 300.0  // 5 minutes
        
        /// GPS Update-Intervalle - 🔧 FIXED: Deutlich weniger aggressiv
        static let foregroundUpdateInterval: TimeInterval = 5.0   // 5 seconds (war: 1.0)
        static let backgroundUpdateInterval: TimeInterval = 30.0  // 30 seconds (war: 10.0)
        
        /// Minimum Bewegungsdistanz für Updates - 🔧 FIXED: Größere Toleranz für weniger Updates
        static let minimumDistanceFilter: Double = 25.0  // 25 meters (war: 5.0)
        
        /// CloudKit Update-Intervall - 🔧 NEW: Separate Kontrolle für CloudKit Updates
        static let cloudKitUpdateInterval: TimeInterval = 30.0  // 30 seconds - nur alle 30s zu CloudKit
        
        /// Map Update-Intervall - 🔧 NEW: Verhindert nervöse Karte durch zu häufige Updates
        static let mapUpdateInterval: TimeInterval = 3.0  // 3 seconds - Map max alle 3s updaten
        
        /// Airspace Update-Intervall - 🔧 NEW: Separate Kontrolle für Airspace Refresh
        static let airspaceUpdateInterval: TimeInterval = 60.0  // 60 seconds - Airspace max alle 60s prüfen
    }

    // MARK: - 🆕 Emergency System Configuration
    struct Emergency {
        /// Emergency detection threshold (m/s) - rapid descent rate
        static let sinkRateThreshold: Double = -10.0  // -10 m/s
        
        /// Emergency detection duration (seconds) - how long condition must persist
        static let detectionDuration: TimeInterval = 10.0  // 10 seconds
        
        /// Emergency cooldown period (prevents spam alerts)
        static let cooldownPeriod: TimeInterval = 300.0  // 5 minutes
        
        /// GPS accuracy requirement for emergency detection
        static let maxGPSAccuracy: Double = 50.0  // 50 meters
    }

    // MARK: - 🆕 Social Features Configuration
    struct Social {
        /// How long to show other pilots (minutes)
        static let pilotRetentionTime: TimeInterval = 15 * 60  // 15 minutes
        
        /// How often to fetch other pilots (seconds)
        static let pilotFetchInterval: TimeInterval = 10  // 10 seconds
        
        /// Maximum distance to show other pilots (meters)
        static let maxPilotDistance: Double = 50_000  // 50 km
        
        /// Default pilot name for new users
        static let defaultPilotName = "Unknown Pilot"
    }

    // MARK: - Dateipfade & ‑Namen
    struct File {
        static let defaultCSVName   = "default.csv"
        static let airspaceJSONName = "airspaces.json"
        static let routeFolder      = "Routes"
        static let exportFolder     = "Exports"
        static let backupFolder     = "Backups"
        static let tempFolder       = "Temp"

        /// Gemeinsamer Formatter für Route‑Dateien
        static let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            df.timeZone = .utc
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }()
        
        /// ISO Date Formatter für CloudKit Timestamps
        static let isoDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            df.timeZone = .utc
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }()
        
        /// Unterstützte Export-Formate
        struct ExportFormats {
            static let gpx = "gpx"
            static let igc = "igc"
            static let csv = "csv"
            static let kml = "kml"
        }
    }
    
    // MARK: - Network Configuration
    struct Network {
        static let timeoutInterval: TimeInterval = 30.0
        static let retryAttempts = 3
        static let retryDelay: TimeInterval = 2.0
        
        /// API Endpoints
        struct Endpoints {
            static let airspace = "/airspaces"
            static let weather = "/weather"
            static let notams = "/notams"
        }
    }
    
    // MARK: - URL Schemes & Deep Links
    struct URLSchemes {
        static let app = "glidertracker"
        static let flight = "flight"
        static let share = "share"
        static let fileImport = "import"  // 'import' ist Swift Keyword, daher fileImport
    }
    
    // MARK: - Siri Shortcuts
    struct SiriShortcuts {
        static let startRecording = "com.glidertracker.start-recording"
        static let stopRecording = "com.glidertracker.stop-recording"
        static let viewFlights = "com.glidertracker.view-flights"
        static let shareLocation = "com.glidertracker.share-location"
    }
    
    // MARK: - Notifications
    struct NotificationNames {
        static let airspaceUpdated = "AirspaceUpdated"
        static let flightStarted = "FlightStarted"
        static let flightStopped = "FlightStopped"
        static let cloudKitSyncCompleted = "CloudKitSyncCompleted"
        static let migrationCompleted = "MigrationCompleted"
        static let pilotPositionsUpdated = "PilotPositionsUpdated"  // 🆕 New notification
        static let emergencyDetected = "EmergencyDetected"  // 🆕 New notification
    }
    
    // MARK: - Error Domains
    struct ErrorDomains {
        static let cloudKit = "GliderTrackerCloudKit"
        static let location = "GliderTrackerLocation"
        static let audio = "GliderTrackerAudio"
        static let fileImport = "GliderTrackerFileImport"
        static let emergency = "GliderTrackerEmergency"  // 🆕 New error domain
    }
    
    // MARK: - App Information
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "org.miggu69.GliderTracker"
}

// MARK: - Environment & Debug Helper
extension AppConstants {
    
    /// Returns true if running in debug/development
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Returns current container identifiers for logging
    static var containerInfo: String {
        return "Primary: \(primaryiCloudContainerID), Legacy: \(legacyiCloudContainerID)"
    }
    
    /// Returns full app version string
    static var fullVersionString: String {
        return "\(appVersion) (\(buildNumber))"
    }
    
    /// Returns current CloudKit environment
    static var cloudKitEnvironment: String {
        return isDebug ? "Development" : "Production"
    }
}
