import SwiftUI
import CoreMotion
import CoreLocation
import WatchKit

class MotionData: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
    private var lastAltitude: Double?
    private var lastUpdateTime: Date?
    private var routeCoordinates = [CLLocationCoordinate2D]()

    @Published var altitude: Double = 0.0
    @Published var variometer: Double = 0.0 {
        didSet {
            handleVariometerChange()
        }
    }
    @Published var speedInKmh: Int = 0
    @Published var isWarningActive: Bool = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        startMotionUpdates()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
            }
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        speedInKmh = Int(location.speed * 3.6)
    }

    private func startMotionUpdates() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            if let currentAltitude = locationManager.location?.altitude {
                self.altitude = currentAltitude
            }
            
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] (altitudeData, error) in
                guard let self = self, let altitudeData = altitudeData, error == nil else {
                    self?.handleUpdateError(error)
                    return
                }

                let currentTime = Date()
                let currentAltitude = altitudeData.relativeAltitude.doubleValue

                DispatchQueue.main.async {
                    if let lastAltitude = self.lastAltitude, let lastUpdateTime = self.lastUpdateTime {
                        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
                        if timeInterval > 0 {
                            let newVario = (currentAltitude - lastAltitude) / timeInterval
                            self.variometer = self.variometer * 0.7 + newVario * 0.3
                        }
                    }

                    self.lastAltitude = currentAltitude
                    self.lastUpdateTime = currentTime
                    
                    if let baseAltitude = self.locationManager.location?.altitude {
                        self.altitude = baseAltitude + currentAltitude
                    }

                    if let currentLocation = self.locationManager.location {
                        self.routeCoordinates.append(currentLocation.coordinate)
                    }
                }
            }
        }
    }

    private func handleVariometerChange() {
        if variometer > 0 {
            playTone(forIntensity: variometer)
            isWarningActive = false
        } else {
            playHaptic(forIntensity: abs(variometer))
            isWarningActive = variometer <= -3.0
        }
    }

    private func playTone(forIntensity intensity: Double) {
        let device = WKInterfaceDevice.current()
        
        if intensity > 0 {
            device.play(.directionUp)
            // Häufigkeit der Töne basierend auf Steigrate
            let delay = max(1.0 - (intensity / 5.0), 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(forIntensity: intensity)
            }
        } else if intensity < 0 {
            device.play(.directionDown)
        }
    }

    private func playHaptic(forIntensity intensity: Double) {
        let hapticType: WKHapticType = intensity > 1.0 ? .success : .failure
        WKInterfaceDevice.current().play(hapticType)
    }

    private func handleUpdateError(_ error: Error?) {
        DispatchQueue.main.async {
            let errorDescription = error?.localizedDescription ?? "Unknown error"
            print("Update Error: \(errorDescription)")
        }
    }

    func resetData() {
        DispatchQueue.main.async {
            self.altitude = 0.0
            self.variometer = 0.0
            self.speedInKmh = 0
            self.routeCoordinates = []
        }
    }

    func saveRoute() {
        let fileName = "route.txt"
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)
        let content = routeCoordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Route saved successfully.")
        } catch {
            print("Failed to save route: \(error.localizedDescription)")
        }
    }
}
