//
//  GliderTrackerViewModel.swift
//  GliderTracker
//
//  Swift-6 compliant • geglättetes Vario • Beep-Trigger  (16 May 2025)
//
import Foundation
import CoreLocation
import Combine
import CoreMotion

@MainActor
final class GliderTrackerViewModel: NSObject,
                                    ObservableObject,
                                    CLLocationManagerDelegate {

    // MARK: – Published
    @Published private(set) var route: [CLLocationCoordinate2D] = []
    @Published var climbRate         = 0.0
    @Published var currentAltitude   = 0.0
    @Published var indicatedAirspeed = 0.0
    @Published var error: String?

    // MARK: – Private
    private let locationManager = CLLocationManager()
    private let motionManager   = CMMotionManager()

    private var lastAlt: (Double, Date)?
    private var climbBuffer: [Double] = []          // Glättung
    private let bufferLimit = 5_000
    private var recording   = false

    // MARK: – Init
    override init() {
        super.init()
        configureLocation()
        configureMotion()
    }

    // MARK: – Tracking
    func startTracking() {
        Task { try? await FileManagerService.shared.startNewRoute() }
        recording = true
        locationManager.startUpdatingLocation()
        motionManager.startDeviceMotionUpdates()
    }

    func stopTracking() async {
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
        AudioService.shared.stop()

        if recording {
            _ = try? await FileManagerService.shared.finishRoute()
            recording = false
        }
    }

    // MARK: – Config
    private func configureLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter  = 5
        locationManager.requestWhenInUseAuthorization()
    }

    private func configureMotion() {
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { _, _ in }
    }

    // MARK: – CLLocationManagerDelegate (Swift 6)
    nonisolated func locationManager(_ mgr: CLLocationManager,
                                     didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }

        Task { @MainActor in self.ingest(loc) }
        Task { try? await FileManagerService.shared.append(location: loc) }
    }

    nonisolated func locationManager(_ mgr: CLLocationManager,
                                     didFailWithError err: Error) {
        Task { @MainActor in self.error = err.localizedDescription }
    }

    // MARK: – Ingest & instruments
    private func ingest(_ loc: CLLocation) {
        // Route-Puffer
        route.append(loc.coordinate)
        if route.count > bufferLimit { route.removeFirst() }

        currentAltitude   = loc.altitude
        indicatedAirspeed = loc.speed * 3.6

        if let last = lastAlt {
            let dt = loc.timestamp.timeIntervalSince(last.1)
            if dt >= 0.8 {                             // nur jeder 0.8 s
                let raw = (loc.altitude - last.0) / dt
                climbBuffer.append(raw)
                if climbBuffer.count > 3 { climbBuffer.removeFirst() }
                climbRate = climbBuffer.reduce(0, +) / Double(climbBuffer.count)
                lastAlt = (loc.altitude, loc.timestamp)
            }
        } else {
            lastAlt = (loc.altitude, loc.timestamp)
        }

        // Beep-Trigger
        AudioService.shared.update(climbRate: climbRate)
    }

    // MARK: – Save-Button
    func saveFlight() {
        Task {
            do {
                if let url = try await FileManagerService.shared.finishRoute() {
                    print("✅ Flight saved to \(url.lastPathComponent)")
                } else {
                    try await FileManagerService.shared.exportGPX(coordinates: route)
                    print("✅ GPX export complete")
                }
            } catch {
                let msg = self.error ?? error.localizedDescription
                print("❌ Save failed: \(msg)")
            }
        }
    }

    // MARK: – File delete helper
    func deleteFile(at url: URL) { try? FileManager.default.removeItem(at: url) }
}
