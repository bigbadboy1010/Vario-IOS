
import Foundation
import CoreLocation

/// Represents a single telemetry sample that we receive for a pilot.
struct PilotPosition: Hashable {
    // MARK: Identity
    /// Unique callsign (or Flarm ID) that identifies the glider/pilot.
    let id: String

    // MARK: Live data
    var name: String?
    var coordinate: CLLocationCoordinate2D
    var altitude: Double          // metres MSL
    var verticalSpeed: Double     // metres / second (+ climb, – sink)
    let timestamp: Date

    // MARK: - Formatted strings (for UI)
    private static let altitudeFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = 0
        return f
    }()

    private static let vsFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    /// Altitude as e.g. “1 235 m”.
    var altitudeString: String {
        Self.altitudeFormatter.string(from: Measurement(value: altitude, unit: UnitLength.meters))
    }

    /// Vertical speed as e.g. “+2.3 m/s” or “–1.0 m/s”.
    var verticalSpeedString: String {
        let formatted = Self.vsFormatter.string(
            from: Measurement(value: verticalSpeed, unit: UnitSpeed.metersPerSecond)
        )
        return verticalSpeed >= 0 ? "▲ \(formatted)" : "▼ \(formatted)"
    }

    /// Relative age, e.g. “12 s ago”.
    var timeAgoString: String {
        let delta = max(0, -timestamp.timeIntervalSinceNow)
        switch delta {
        case ..<90:
            return "\(Int(delta)) s ago"
        case ..<3600:
            return "\(Int(delta / 60)) min ago"
        default:
            return "\(Int(delta / 3600)) h ago"
        }
    }

    // MARK: Equatable/Hashable (manual so we ignore high‑churn properties)
    static func == (lhs: PilotPosition, rhs: PilotPosition) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
    }
}
