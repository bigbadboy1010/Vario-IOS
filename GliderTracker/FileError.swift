//
//  FileError.swift
//  GliderTracker
//
//  Created by François De Lattre
//  Copyright © 2024 @Miggu69. All rights reserved.
//

import Foundation

enum FileError: LocalizedError {
    // MARK: - Error Cases
    case iCloudNotFound(reason: String? = nil)
    case directoryCreationFailed(path: String)
    case fileWriteFailed(path: String, reason: String)
    case fileNotFound(path: String)
    case fileAccessDenied(path: String)
    case invalidPath(path: String)
    case quotaExceeded
    case insufficientSpace
    case syncFailed(reason: String)
    case backupFailed(reason: String)
    case compressionFailed(reason: String)
    case invalidFileFormat(expected: String, found: String)
    
    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        case .iCloudNotFound(let reason):
            return "iCloud-Verzeichnis nicht gefunden\(reason.map { ": \($0)" } ?? "")"
            
        case .directoryCreationFailed(let path):
            return "Fehler beim Erstellen des Ordners: \(path)"
            
        case .fileWriteFailed(let path, let reason):
            return "Fehler beim Speichern der Datei '\(path)': \(reason)"
            
        case .fileNotFound(let path):
            return "Datei nicht gefunden: \(path)"
            
        case .fileAccessDenied(let path):
            return "Zugriff verweigert auf: \(path)"
            
        case .invalidPath(let path):
            return "Ungültiger Dateipfad: \(path)"
            
        case .quotaExceeded:
            return "iCloud Speicherplatz ist voll"
            
        case .insufficientSpace:
            return "Nicht genügend Speicherplatz verfügbar"
            
        case .syncFailed(let reason):
            return "iCloud Synchronisation fehlgeschlagen: \(reason)"
            
        case .backupFailed(let reason):
            return "Backup fehlgeschlagen: \(reason)"
            
        case .compressionFailed(let reason):
            return "Komprimierung fehlgeschlagen: \(reason)"
            
        case .invalidFileFormat(let expected, let found):
            return "Ungültiges Dateiformat: Erwartet '\(expected)', gefunden '\(found)'"
        }
    }
    
    // MARK: - Additional Error Information
    var failureReason: String? {
        switch self {
        case .iCloudNotFound:
            return "iCloud ist möglicherweise nicht aktiviert oder nicht verfügbar"
            
        case .directoryCreationFailed:
            return "Fehlende Berechtigungen oder ungültiger Pfad"
            
        case .fileWriteFailed:
            return "Schreibvorgang konnte nicht abgeschlossen werden"
            
        case .fileNotFound:
            return "Die angeforderte Datei existiert nicht"
            
        case .fileAccessDenied:
            return "Keine ausreichenden Berechtigungen"
            
        case .invalidPath:
            return "Der Dateipfad ist ungültig oder nicht erreichbar"
            
        case .quotaExceeded:
            return "Das iCloud Speicherkontingent ist erschöpft"
            
        case .insufficientSpace:
            return "Nicht genügend freier Speicherplatz auf dem Gerät"
            
        case .syncFailed:
            return "Die Synchronisation mit iCloud konnte nicht abgeschlossen werden"
            
        case .backupFailed:
            return "Die Backup-Operation konnte nicht abgeschlossen werden"
            
        case .compressionFailed:
            return "Die Datei konnte nicht komprimiert werden"
            
        case .invalidFileFormat:
            return "Das Dateiformat entspricht nicht den Erwartungen"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .iCloudNotFound:
            return "Überprüfen Sie Ihre iCloud-Einstellungen und stellen Sie sicher, dass Sie angemeldet sind"
            
        case .directoryCreationFailed:
            return "Überprüfen Sie die Zugriffsrechte und den verfügbaren Speicherplatz"
            
        case .fileWriteFailed:
            return "Stellen Sie sicher, dass genügend Speicherplatz verfügbar ist und die App Schreibrechte hat"
            
        case .fileNotFound:
            return "Überprüfen Sie, ob die Datei an einem anderen Ort gespeichert wurde oder erstellen Sie sie neu"
            
        case .fileAccessDenied:
            return "Überprüfen Sie die App-Berechtigungen in den Einstellungen"
            
        case .invalidPath:
            return "Versuchen Sie, die Datei an einem anderen Ort zu speichern"
            
        case .quotaExceeded:
            return "Löschen Sie nicht benötigte Dateien oder erweitern Sie Ihren iCloud Speicherplatz"
            
        case .insufficientSpace:
            return "Löschen Sie nicht benötigte Dateien, um Speicherplatz freizugeben"
            
        case .syncFailed:
            return "Überprüfen Sie Ihre Internetverbindung und versuchen Sie es später erneut"
            
        case .backupFailed:
            return "Stellen Sie sicher, dass genügend Speicherplatz verfügbar ist und versuchen Sie es erneut"
            
        case .compressionFailed:
            return "Versuchen Sie es mit einer niedrigeren Komprimierungsstufe"
            
        case .invalidFileFormat:
            return "Stellen Sie sicher, dass die Datei im korrekten Format vorliegt"
        }
    }
    
    // MARK: - Helper Methods
    var errorCode: Int {
        switch self {
        case .iCloudNotFound: return 1001
        case .directoryCreationFailed: return 1002
        case .fileWriteFailed: return 1003
        case .fileNotFound: return 1004
        case .fileAccessDenied: return 1005
        case .invalidPath: return 1006
        case .quotaExceeded: return 1007
        case .insufficientSpace: return 1008
        case .syncFailed: return 1009
        case .backupFailed: return 1010
        case .compressionFailed: return 1011
        case .invalidFileFormat: return 1012
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .quotaExceeded, .insufficientSpace, .syncFailed:
            return true
        default:
            return false
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .iCloudNotFound, .fileAccessDenied, .quotaExceeded:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomDebugStringConvertible
extension FileError: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        FileError:
        - Type: \(String(describing: self))
        - Code: \(errorCode)
        - Description: \(errorDescription ?? "No description")
        - Reason: \(failureReason ?? "No reason provided")
        - Recovery: \(recoverySuggestion ?? "No recovery suggestion")
        - Recoverable: \(isRecoverable)
        - Requires User Action: \(requiresUserAction)
        """
    }
}
