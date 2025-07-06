//
//  FileManagerService.swift
//  GliderTracker
//
//  🔧 ROBUST VERSION: Proper error handling and file existence checks
//

import Foundation
import CoreLocation

final class FileManagerService {

    // MARK: – Singleton
    static let shared = FileManagerService()
    private init() {}

    // MARK: – Private Properties
    private var csvHandle: FileHandle?
    private var currentFolder: URL?

    // MARK: – Public API
    @MainActor
    func startNewRoute() async throws {
        let folder = try makeFlightFolder(for: Date())
        let csvURL = folder.appendingPathComponent("track.csv")

        let header = "timestamp,latitude,longitude,altitude,speed\n"
        try header.data(using: .utf8)?.write(to: csvURL)

        csvHandle = try FileHandle(forWritingTo: csvURL)
        csvHandle?.seekToEndOfFile()
        currentFolder = folder
    }

    @MainActor
    func append(location: CLLocation) async throws {
        guard let h = csvHandle else { return }
        let line = String(format: "%.3f,%.6f,%.6f,%.1f,%.1f\n",
                           location.timestamp.timeIntervalSince1970,
                           location.coordinate.latitude,
                           location.coordinate.longitude,
                           location.altitude,
                           location.speed)
        if let data = line.data(using: .utf8) { h.write(data) }
    }

    @discardableResult
    @MainActor
    func finishRoute() async throws -> URL? {
        defer { csvHandle = nil; currentFolder = nil }
        try csvHandle?.close()
        return currentFolder
    }

    @MainActor
    func exportGPX(coordinates: [CLLocationCoordinate2D]) async throws {
        guard !coordinates.isEmpty else { return }
        let folder = try makeFlightFolder(for: Date())
        let gpxURL = folder.appendingPathComponent("track.gpx")

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GliderTracker">
          <trk><name>Flight</name><trkseg>
        """

        for c in coordinates {
            gpx += String(format: "    <trkpt lat=\"%.6f\" lon=\"%.6f\" />\n",
                          c.latitude, c.longitude)
        }
        gpx += "  </trkseg></trk>\n</gpx>"

        try gpx.data(using: .utf8)?.write(to: gpxURL)
    }

    /// Liefert alle vorhandenen Flug-Ordner sortiert (neu → alt) - MIT EXISTENCE CHECK
    func listFlightFolders() -> [URL] {
        let root = baseContainer.appendingPathComponent(AppConstants.File.routeFolder)
        
        // Ensure the root directory exists
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create routes directory: \(error)")
            return []
        }
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ Failed to read routes directory contents")
            return []
        }
        
        // Filter only existing directories and validate they contain actual flight data
        let validFolders = contents.compactMap { url -> (URL, Date)? in
            // Check if it's a directory
            guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory == true else {
                return nil
            }
            
            // Check if directory still exists (important for iCloud sync)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️ Skipping non-existent directory: \(url.lastPathComponent)")
                return nil
            }
            
            // Get modification date for sorting
            let modificationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            
            // Validate that it contains flight data (at least one file)
            if let dirContents = try? FileManager.default.contentsOfDirectory(atPath: url.path),
               !dirContents.isEmpty {
                return (url, modificationDate)
            } else {
                print("⚠️ Skipping empty directory: \(url.lastPathComponent)")
                return nil
            }
        }
        
        // Sort by modification date (newest first)
        return validFolders
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    /// Safe file deletion with proper error handling
    func deleteFolder(at url: URL) -> Bool {
        // Double-check existence before deletion
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ Cannot delete - folder doesn't exist: \(url.path)")
            return true // Consider this success since the goal (file gone) is achieved
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Successfully deleted folder: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to delete folder \(url.lastPathComponent): \(error)")
            return false
        }
    }
    
    /// Check if a file/folder exists and is accessible
    func exists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Get safe file info for UI display
    func getFileInfo(for url: URL) -> (size: String, date: String)? {
        guard exists(at: url) else { return nil }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int64 ?? 0
            let date = attrs[.modificationDate] as? Date ?? Date()
            
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let dateString = formatter.string(from: date)
            
            return (size: sizeString, date: dateString)
        } catch {
            print("❌ Failed to get file info for \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: – Private Methods
    
    /// iCloud-Ordner, falls vorhanden, sonst „On My iPhone"
    private var baseContainer: URL {
        if let icloud = FileManager.default
            .url(forUbiquityContainerIdentifier: AppConstants.primaryiCloudContainerID) {
            return icloud
        }
        return FileManager.default.urls(for: .documentDirectory,
                                        in: .userDomainMask).first!
    }

    private func makeFlightFolder(for date: Date) throws -> URL {
        let name = AppConstants.File.dateFormatter.string(from: date)
        let folder = baseContainer
            .appendingPathComponent(AppConstants.File.routeFolder, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)

        try FileManager.default.createDirectory(at: folder,
                                                withIntermediateDirectories: true)
        return folder
    }
}

// MARK: - Extension for ViewModel Integration
extension FileManagerService {
    /// Safe deletion method for ViewModel
    @discardableResult
    func safeDelete(at url: URL) -> Bool {
        return deleteFolder(at: url)
    }
}
