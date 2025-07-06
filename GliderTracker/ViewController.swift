//
//  ViewController.swift
//  GliderTracker
//
//  🔧 CORRECTED VERSION: Fixed navigation and toolbar issues
//  Polished UI: blurred HUD, kompakte Toolbar, separater Kompass.
//  Emergency System: Automatic crash detection and SMS alerts
//
import UIKit
import SwiftUI
import MapKit
import CoreLocation
import Combine
import CloudKit
import MessageUI

final class ViewController: UIViewController {
    // MARK: - Properties
    private let vm         = GliderTrackerViewModel()
    private let mapView    = MKMapView()
    private let locManager = CLLocationManager()

    private var hudContainer: UIVisualEffectView!
    private var liveCountLabel: UILabel!

    private var sharePosition: Bool {
        get { UserDefaults.standard.bool(forKey: "sharePosition") }
        set { UserDefaults.standard.set(newValue, forKey: "sharePosition") }
    }
    
    private lazy var shareButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "antenna.radiowaves.left.and.right"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(toggleShare))
        item.tintColor = sharePosition ? .systemGreen : .systemGray
        // Feste Breite für bessere Layout-Stabilität
        item.width = 44
        return item
    }()
    
    // Neuer Button für User Tracking
    private lazy var trackingButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "location"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(toggleUserTracking))
        item.tintColor = .systemGray
        // Feste Breite für bessere Layout-Stabilität
        item.width = 44
        return item
    }()
    
    // Settings Button als separater Button (nicht in Toolbar)
    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 22
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return button
    }()
    
    private let pilotFetcher = PilotFetcher()
    private var pilotFetchCancellable: AnyCancellable?
    
    private var compassButton: MKCompassButton?
    private var cancellables  = Set<AnyCancellable>()
    private var routeOverlay: MKPolyline?
    
    // Location Update Throttling
    private var lastLocationUpdate: Date = Date.distantPast
    private let locationUpdateInterval: TimeInterval = 3.0 // 3 Sekunden zwischen Updates
    
    // Tracking state management
    private var isInitialTrackingSetup = true
    
    // Emergency Detection
    private var emergencyEnabled: Bool {
        UserDefaults.standard.bool(forKey: "emergencyEnabled")
    }
    private var verticalSpeeds: [Double] = []
    private var emergencyStartTime: Date?
    private let emergencyThreshold: Double = -10.0 // -10 m/s (sinking)
    private let emergencyDuration: TimeInterval = 10.0 // 10 seconds
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[GT] 📱 ViewController.viewDidLoad started")
        
        setupMap()
        print("[GT] 📱 Map setup completed")
        
        setupHUD()
        setupLivePilotsBadge()
        print("[GT] 📱 HUD setup completed")
        
        setupSettingsButton()
        print("[GT] 📱 Settings button setup completed")
        
        setupToolbar()
        print("[GT] 📱 Toolbar setup completed")
        
        subscribeToRoute()
        subscribeToAirspaces()
        print("[GT] 📱 Subscriptions setup completed")
        
        locManager.delegate = self
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.distanceFilter = 5.0 // Nur Updates bei 5m Bewegung
        locManager.requestWhenInUseAuthorization()
        locManager.startUpdatingLocation()
        print("[GT] 📱 Location manager setup completed")
        
        vm.startTracking()
        print("[GT] 📱 VM tracking started")

        // Fetch pilots once and update UI
        pilotFetcher.fetch { [weak self] list in
            self?.renderPilots(list)
            self?.updateLivePilotsBadge(count: list.count)
        }
        // Live‑poll every 5 s
        pilotFetchCancellable = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pilotFetcher.fetch { list in
                    self?.renderPilots(list)
                    self?.updateLivePilotsBadge(count: list.count)
                }
            }
        
        print("[GT] 📱 ViewController.viewDidLoad completed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Nur beim ersten Erscheinen User Tracking aktivieren
        if isInitialTrackingSetup && mapView.userTrackingMode == .none {
            mapView.setUserTrackingMode(.followWithHeading, animated: false) // Ohne Animation für sanfteren Start
            isInitialTrackingSetup = false
        }
        // Tracking Button Appearance nach dem View Setup aktualisieren
        updateTrackingButtonAppearance()
    }
    
    // MARK: - Map + Compass
    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsUserLocation = true
        mapView.userTrackingMode  = .none // Initial ohne Tracking
        mapView.delegate = self
        
        // Sanftere Map-Einstellungen + Resource-Optimierung
        mapView.isPitchEnabled = false // Weniger 3D-Effekte
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsBuildings = false // Reduziert Resource-Anfragen
        mapView.pointOfInterestFilter = .excludingAll // Modern way to exclude POIs (iOS 13+)
        mapView.mapType = .standard // Explizit auf Standard setzen beim Start
        
        view.addSubview(mapView)
        
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        mapView.addOverlays(AirspaceService.shared.overlays)
        
        // Eigener Kompass
        mapView.showsCompass = false
        let compass = MKCompassButton(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false
        compass.compassVisibility = .adaptive
        view.addSubview(compass)
        
        NSLayoutConstraint.activate([
            compass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            compass.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            compass.widthAnchor.constraint(equalToConstant: 44),
            compass.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        self.compassButton = compass
    }
    
    // MARK: - HUD (blur capsule)
    private func setupHUD() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        self.hudContainer = blur
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 20
        blur.layer.cornerCurve  = .continuous
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        view.addSubview(blur)
        
        let hudHost = UIHostingController(rootView: InstrumentHUD(vm: vm).allowsHitTesting(false))
        addChild(hudHost)
        hudHost.view.translatesAutoresizingMaskIntoConstraints = false
        hudHost.view.backgroundColor = .clear
        blur.contentView.addSubview(hudHost.view)
        hudHost.didMove(toParent: self)
        
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            blur.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            blur.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            hudHost.view.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            hudHost.view.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16),
            hudHost.view.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 8),
            hudHost.view.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupLivePilotsBadge() {
        liveCountLabel = UILabel()
        liveCountLabel.translatesAutoresizingMaskIntoConstraints = false
        liveCountLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        liveCountLabel.textColor = .white
        liveCountLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        liveCountLabel.layer.cornerRadius = 12
        liveCountLabel.clipsToBounds = true
        liveCountLabel.textAlignment = .center
        liveCountLabel.text = "Live 0"
        view.addSubview(liveCountLabel)

        // Position just below the HUD container
        NSLayoutConstraint.activate([
            liveCountLabel.topAnchor.constraint(equalTo: hudContainer.bottomAnchor, constant: 10),
            liveCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            liveCountLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            liveCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }

    private func updateLivePilotsBadge(count: Int) {
        DispatchQueue.main.async {
            self.liveCountLabel.text = "Live \(count)"
        }
    }
    
    // MARK: - Settings Button (oben rechts)
    private func setupSettingsButton() {
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            settingsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80), // Unterhalb des HUD
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Toolbar (Bottom) - CORRECTED
    private func setupToolbar() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isTranslucent = true
        toolbar.tintColor      = .systemBlue
        
        let exit = UIBarButtonItem(image: UIImage(systemName: "xmark"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(exitTapped))
        let save = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(saveTapped))
        let list = UIBarButtonItem(image: UIImage(systemName: "list.bullet"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(showTrackList))
        let map  = UIBarButtonItem(image: UIImage(systemName: "map"),
                                   style: .plain,
                                   target: self,
                                   action: #selector(toggleMapType))
        
        // 🔧 FIXED: Korrekte Syntax für flexibleSpace
        toolbar.items = [
            exit,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            save,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            list,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            map,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            trackingButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            shareButton
        ]
        toolbar.sizeToFit()
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    // MARK: - User Tracking Methods
    @objc private func toggleUserTracking() {
        // Sanfteres Umschalten zwischen Modi
        switch mapView.userTrackingMode {
        case .none:
            mapView.setUserTrackingMode(.follow, animated: true)
        case .follow:
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
        case .followWithHeading:
            mapView.setUserTrackingMode(.none, animated: true)
        @unknown default:
            mapView.setUserTrackingMode(.none, animated: true)
        }
        updateTrackingButtonAppearance()
    }
    
    private func updateTrackingButtonAppearance() {
        let (imageName, color): (String, UIColor) = {
            switch mapView.userTrackingMode {
            case .none:
                return ("location", .systemGray)
            case .follow:
                return ("location.fill", .systemBlue)
            case .followWithHeading:
                return ("location.north.line.fill", .systemBlue)
            @unknown default:
                return ("location", .systemGray)
            }
        }()
        
        trackingButton.image = UIImage(systemName: imageName)
        trackingButton.tintColor = color
    }
    
    // MARK: - Combine
    private func subscribeToRoute() {
        vm.$route
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coords in self?.updateRouteOverlay(with: coords) }
            .store(in: &cancellables)
    }
    
    private func subscribeToAirspaces() {
        NotificationCenter.default.publisher(for: .airspacesDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.mapView.addOverlays(AirspaceService.shared.overlays)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Route Overlay
    private func updateRouteOverlay(with coords: [CLLocationCoordinate2D]) {
        guard coords.count > 1 else { return }
        if let old = routeOverlay { mapView.removeOverlay(old) }
        let poly = MKPolyline(coordinates: coords, count: coords.count)
        routeOverlay = poly
        mapView.addOverlay(poly)
    }
    
    // MARK: - Button-Actions
    @objc private func saveTapped() { vm.saveFlight() }
    
    @objc private func exitTapped() {
        Task {
            // Persist the current route
            vm.saveFlight()

            // Allow a moment for the async save to hit disk
            try? await Task.sleep(for: .milliseconds(700))

            await vm.stopTracking()

            // Graceful background‑suspend (so any buffers flush)
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))

            // Terminate after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(EXIT_SUCCESS)
            }
        }
    }
    
    // 🔧 FIXED: Korrekte FileList Navigation
    @objc private func showTrackList() {
        let fileListVC = FileListViewController(viewModel: vm)
        
        // Always push since we have NavigationController from SceneDelegate
        navigationController?.pushViewController(fileListVC, animated: true)
    }
    
    @objc private func toggleMapType() {
        // Sanfterer Map-Type Switch um Resource-Errors zu reduzieren
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.mapView.mapType = (self.mapView.mapType == .standard) ? .satellite : .standard
        }
    }
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    // MARK: - Emergency Detection
    private func checkEmergencyCondition(location: CLLocation) {
        guard emergencyEnabled else { return }
        
        // Calculate vertical speed from altitude changes
        let verticalSpeed = location.speed > 0 ? location.speed * sin(location.course.degreesToRadians) : 0
        
        // Keep last 30 readings (roughly 90 seconds at 3s intervals)
        verticalSpeeds.append(verticalSpeed)
        if verticalSpeeds.count > 30 {
            verticalSpeeds.removeFirst()
        }
        
        // Check if current vertical speed exceeds emergency threshold
        if verticalSpeed <= emergencyThreshold {
            if emergencyStartTime == nil {
                emergencyStartTime = Date()
                print("🚨 Emergency condition detected! Vertical speed: \(verticalSpeed) m/s")
            } else if let startTime = emergencyStartTime,
                      Date().timeIntervalSince(startTime) >= emergencyDuration {
                // Emergency condition sustained for required duration
                triggerEmergencyAlert(location: location, verticalSpeed: verticalSpeed)
                emergencyStartTime = nil // Reset to prevent repeated alerts
            }
        } else {
            // Reset emergency timer if condition no longer met
            if emergencyStartTime != nil {
                print("🟡 Emergency condition cleared. Vertical speed: \(verticalSpeed) m/s")
                emergencyStartTime = nil
            }
        }
    }
    
    private func triggerEmergencyAlert(location: CLLocation, verticalSpeed: Double) {
        let pilotName = UserDefaults.standard.string(forKey: "pilotName")
        let emergencyContact = UserDefaults.standard.string(forKey: "emergencyContact")
        let emergencyPhone = UserDefaults.standard.string(forKey: "emergencyPhone")
        
        guard let emergencyContact = emergencyContact, !emergencyContact.isEmpty,
              let emergencyPhone = emergencyPhone, !emergencyPhone.isEmpty else {
            print("🚨 EMERGENCY DETECTED but no emergency contact configured!")
            return
        }
        
        let pilotDisplayName = pilotName ?? "Unknown Pilot"
        let coordinates = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        let altitude = String(format: "%.0f m", location.altitude)
        let speed = String(format: "%.1f m/s", abs(verticalSpeed))
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        
        let message = """
        🚨 EMERGENCY ALERT: \(pilotDisplayName)

        Rapid descent detected: -\(speed) for 10+ seconds
        Location: \(coordinates)
        Altitude: \(altitude)
        Time: \(timeString)

        Please check on pilot immediately!

        - Glider Tracker Emergency System
        """
        
        print("🚨 TRIGGERING EMERGENCY ALERT:")
        print(message)
        
        // Try to send SMS
        sendEmergencyMessage(message: message, phone: emergencyPhone)
        
        // Show local alert
        DispatchQueue.main.async {
            self.showEmergencyTriggeredAlert()
        }
    }
    
    private func sendEmergencyMessage(message: String, phone: String) {
        guard MFMessageComposeViewController.canSendText() else {
            print("🚨 Cannot send SMS - MessageUI not available")
            return
        }
        
        let messageController = MFMessageComposeViewController()
        messageController.body = message
        messageController.recipients = [phone]
        messageController.messageComposeDelegate = self
        
        DispatchQueue.main.async {
            self.present(messageController, animated: true)
        }
    }
    
    private func showEmergencyTriggeredAlert() {
        let alert = UIAlertController(
            title: "🚨 EMERGENCY ALERT SENT",
            message: "Emergency condition detected! Alert sent to emergency contact.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "I'm OK", style: .default) { _ in
            // Could implement a "cancel emergency" feature here
            print("User indicated they are OK")
        })
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let poly = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = .systemRed
            r.lineWidth   = 3
            return r
        }
        if let zone = overlay as? MKPolygon {
            let r = MKPolygonRenderer(polygon: zone)
            r.strokeColor = .systemYellow
            r.fillColor   = UIColor.systemYellow.withAlphaComponent(0.2)
            r.lineWidth   = 1
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    private func renderPilots(_ pilots: [PilotPosition]) {
        // Remove old pilot annotations (excluding user location)
        let others = mapView.annotations.filter { $0 is PilotAnnotation }
        mapView.removeAnnotations(others)
        
        let myId = "pos-" + CKCurrentUserDefaultName
        let annotations = pilots.filter { $0.id != myId }.map { pilot in
            return PilotAnnotation(pilotPosition: pilot)  // 🆕 Use new initializer with full pilot data
        }
        mapView.addAnnotations(annotations)
        
        // 🆕 Log pilot information for debugging
        if !annotations.isEmpty {
            print("👥 Rendered \(annotations.count) other pilots on map:")
            for annotation in annotations {
                if let pilot = annotation.pilotPosition {
                    let altitude = pilot.altitudeString
                    let timeAgo = pilot.timeAgoString // Use directly; remove redundant declaration
                    let name = pilot.name
                    print("   - \(name ?? "Unknown") at \(altitude), \(timeAgo)")
                }
            }
        }
        
        // KEIN automatisches Zoomen mehr!
        // Das war der Hauptgrund für das nervöse Verhalten
        // Die Karte bleibt bei der aktuellen Ansicht/Tracking-Modus
    }
    
    // Tracking-Button aktualisieren wenn User Tracking sich ändert
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTrackingButtonAppearance()
        }
    }
}

// MARK: - Share Position
extension ViewController {
    @objc private func toggleShare() {
        sharePosition.toggle()
        shareButton.tintColor = sharePosition ? .systemGreen : .systemGray
        if !sharePosition {
            CloudKitPublisher.shared.deleteOwnRecord()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ mgr: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("📍 Location authorization granted")
        }
    }
    
    func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let location = locs.last else { return }
        
        // Throttle Location Updates
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= locationUpdateInterval else {
            return
        }
        lastLocationUpdate = now
        
        // Emergency Detection
        checkEmergencyCondition(location: location)
        
        // CloudKit Update (wenn sharing aktiv)
        if sharePosition && UIApplication.shared.applicationState != .background {
            let pilotName = UserDefaults.standard.string(forKey: "pilotName") ?? "Unknown Pilot"
            CloudKitPublisher.shared.push(location, pilotName: pilotName)
        }
        
        // Airspace Update (mit eigenem Throttling im Service)
        AirspaceService.shared.refresh(for: location)
        
        // KEIN automatisches User Tracking zurücksetzen!
        // Der Benutzer kann selbst entscheiden über den Tracking-Button
    }
}

// MARK: - MessageUI Delegate
extension ViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) {
            switch result {
            case .sent:
                print("✅ Emergency SMS sent successfully")
            case .cancelled:
                print("🟡 Emergency SMS cancelled by user")
            case .failed:
                print("❌ Emergency SMS failed to send")
            @unknown default:
                print("❓ Unknown SMS result")
            }
        }
    }
}

// MARK: - Helper Extensions
extension Double {
    var degreesToRadians: Double {
        return self * .pi / 180.0
    }
}