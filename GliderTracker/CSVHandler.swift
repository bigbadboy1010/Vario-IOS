//
//  CSVHandler.swift
//  GliderTracker
//
//  Build‑fix 04 May 2025
//  ──────────────────────────────────────────────────────────
//  ▸ Fixed `split(whereSeparator:)` syntax (no stray \n)
//  ▸ Removed superfluous `try` in non‑throwing context
//  ▸ Added missing `public` access for `headerLine` (used by FileManagerService)
//  ▸ `actor CSVHandler` (removed misguided @globalActor)
//

import Foundation
import CoreLocation

// MARK: - Model

public struct RouteSample: Sendable, Equatable, Codable {
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double   // metres
    public let speed: Double      // m / s

    public init(timestamp: Date, latitude: Double, longitude: Double, altitude: Double, speed: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
    }

    public init(from location: CLLocation) {
        self.init(timestamp: location.timestamp,
                  latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  altitude: location.altitude,
                  speed: location.speed)
    }
}

// MARK: - CSV Errors

enum CSVError: LocalizedError, Sendable {
    case emptyInput
    case headerMismatch([String])
    case invalidDate(String)
    case invalidNumber(String, column: String)
    case outOfRange(String, column: String, min: Double, max: Double)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:                "CSV input is empty."
        case .headerMismatch(let hdr):   "Unexpected CSV header: \(hdr.joined(separator: ", "))."
        case .invalidDate(let raw):      "Invalid ISO‑8601 date: ‘\(raw)’."
        case .invalidNumber(let raw, let col): "Non‑numeric ‘\(raw)’ in column ‘\(col)’."
        case .outOfRange(let raw, let col, let min, let max): "Value ‘\(raw)’ in column ‘\(col)’ must be between \(min) and \(max)."
        case .writeFailed(let reason):   "Failed to write CSV: \(reason)"
        }
    }
}

// MARK: - CSV Handler (Actor)

actor CSVHandler {
    static let shared = CSVHandler()
    private init() {}

    // Standard header order
    public static let header = ["timestamp", "latitude", "longitude", "altitude", "speed"]
    public static var headerLine: String { header.joined(separator: ",") }

    private let dateFormatter: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        df.timeZone = .utc
        return df
    }()

    // MARK: Decoding

    func decode(_ csv: String) throws -> [RouteSample] {
        let lines = csv.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard !lines.isEmpty else { throw CSVError.emptyInput }

        let headerColumns = lines[0].split(separator: ",").map(String.init)
        guard headerColumns == Self.header else { throw CSVError.headerMismatch(headerColumns) }

        var samples: [RouteSample] = []
        samples.reserveCapacity(lines.count - 1)

        for (index, line) in lines.dropFirst().enumerated() {
            let cols = line.split(separator: ",").map(String.init)
            guard cols.count == Self.header.count else {
                throw CSVError.writeFailed("Line \(index + 2): expected \(Self.header.count) columns, got \(cols.count)")
            }

            guard let date = dateFormatter.date(from: cols[0]) else { throw CSVError.invalidDate(cols[0]) }
            let lat = try parseDouble(cols[1], column: "latitude", range: -90...90)
            let lon = try parseDouble(cols[2], column: "longitude", range: -180...180)
            let alt = try parseDouble(cols[3], column: "altitude", range: -500...30_000)
            let spd = try parseDouble(cols[4], column: "speed", range: 0...200)

            samples.append(RouteSample(timestamp: date, latitude: lat, longitude: lon, altitude: alt, speed: spd))
        }
        return samples
    }

    // MARK: Encoding (in‑memory)

    func encode(_ samples: [RouteSample]) throws -> String {
        guard !samples.isEmpty else { throw CSVError.emptyInput }

        var csv = Self.headerLine + "\n"
        csv.reserveCapacity(samples.count * 64)

        for s in samples {
            csv.append(dateFormatter.string(from: s.timestamp))
            csv.append(",")
            csv.append(String(format: "%.6f", s.latitude))
            csv.append(",")
            csv.append(String(format: "%.6f", s.longitude))
            csv.append(",")
            csv.append(String(format: "%.1f", s.altitude))
            csv.append(",")
            csv.append(String(format: "%.2f", s.speed))
            csv.append("\n")
        }
        return csv
    }

    // MARK: Streaming encoder (file‑output)

    func encode<S: Sequence>(samples: S, to url: URL) async throws where S.Element == RouteSample {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        if let headerData = (Self.headerLine + "\n").data(using: .utf8) {
            try handle.write(contentsOf: headerData)
        }

        for sample in samples {
            let line = [
                dateFormatter.string(from: sample.timestamp),
                String(format: "%.6f", sample.latitude),
                String(format: "%.6f", sample.longitude),
                String(format: "%.1f", sample.altitude),
                String(format: "%.2f", sample.speed)
            ].joined(separator: ",") + "\n"
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        }
    }

    // MARK: Validation
    func validate(_ csv: String) -> Bool { (try? decode(csv)) != nil }

    // MARK: Helpers
    private func parseDouble(_ raw: String, column: String, range: ClosedRange<Double>) throws -> Double {
        guard let value = Double(raw) else { throw CSVError.invalidNumber(raw, column: column) }
        guard range.contains(value) else {
            throw CSVError.outOfRange(raw, column: column, min: range.lowerBound, max: range.upperBound)
        }
        return value
    }
}
