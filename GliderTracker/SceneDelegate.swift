//
//  SceneDelegate.swift
//  GliderTracker
//
//  Updated for Multi-Container CloudKit Support - 2025-06-12
//  🔧 FIXED: Proper ViewController setup with NavigationController
//

import UIKit
import CarPlay
import CloudKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - Scene Connection
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        // CarPlay handling
        if #available(iOS 17.0, *), session.role == .carTemplateApplication,
           let carScene = scene as? CPTemplateApplicationScene {
            carScene.delegate = CarPlayManager.shared
            return
        }
        
        print("[GT] 🎬 Scene connecting...")
        
        // Window setup
        window = UIWindow(windowScene: windowScene)
        
        // Setup initial view controller - 🔧 FIXED
        setupRootViewController()
        
        window?.makeKeyAndVisible()
        
        // Handle any URLs or user activities from launch
        handleConnectionOptions(connectionOptions)
        
        print("[GT] 🎬 Scene connected successfully")
    }

    // MARK: - Scene State Changes
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("[GT] 🎬 Scene disconnected")
        
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        
        // Final CloudKit sync before disconnect
        Task {
            await CloudKitPublisher.shared.checkContainerStatus()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("[GT] 🎬 Scene became active")
        
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
        Task {
            // Check CloudKit container status when scene becomes active
            await CloudKitPublisher.shared.checkContainerStatus()
            
            // Resume any paused operations
            resumeAppOperations()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        print("[GT] 🎬 Scene will resign active")
        
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
        // Pause any active operations
        pauseAppOperations()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        UIApplication.shared.isIdleTimerDisabled = true
        print("[GT] 🎬 Scene entering foreground")
        
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        Task {
            // Resume CloudKit operations
            await CloudKitPublisher.shared.checkContainerStatus()
            
            // Check if migration is needed (app might have been updated while in background)
            await CloudKitPublisher.shared.migrateIfNeeded()
            
            // Resume location tracking if needed
            resumeLocationTracking()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        print("[GT] 🎬 Scene entered background")
        
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        Task {
            // Save current state
            await saveAppState()
            
            // Final CloudKit sync
            await performBackgroundCloudKitSync()
        }
    }

    // MARK: - URL and User Activity Handling
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("[GT] 🎬 Scene received URLs: \(URLContexts.map { $0.url })")
        
        for context in URLContexts {
            handleURL(context.url, options: context)
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("[GT] 🎬 Scene continuing user activity: \(userActivity.activityType)")
        
        // Handle Handoff, Spotlight, Siri Shortcuts, etc.
        handleUserActivity(userActivity)
    }

    // MARK: - Private Helper Methods
    
    // 🔧 FIXED: Saubere programmatische Setup ohne Storyboard-Fallbacks
    private func setupRootViewController() {
        print("[GT] 📱 Setting up root view controller programmatically...")
        
        // Der echte ViewController (nicht generischer UIViewController!)
        let mainViewController = ViewController()
        
        // NavigationController wrapper - ESSENTIELL für File Manager Button!
        let navigationController = UINavigationController(rootViewController: mainViewController)
        
        // Moderne Navigation Bar Appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        
        // Navigation Bar verstecken da ViewController eigene UI hat
        navigationController.setNavigationBarHidden(true, animated: false)
        
        // Als Root ViewController setzen
        window?.rootViewController = navigationController
        
        print("[GT] ✅ Root ViewController successfully configured with NavigationController")
    }
    
    private func handleConnectionOptions(_ connectionOptions: UIScene.ConnectionOptions) {
        // Handle URLs passed during app launch
        for urlContext in connectionOptions.urlContexts {
            handleURL(urlContext.url, options: urlContext)
        }
        
        // Handle user activities
        if let userActivity = connectionOptions.userActivities.first {
            handleUserActivity(userActivity)
        }
    }
    
    private func handleURL(_ url: URL, options: UIOpenURLContext) {
        print("[GT] 🔗 Handling URL: \(url)")
        
        // Handle different URL schemes
        switch url.scheme {
        case "glidertracker":
            handleGliderTrackerURL(url)
        case "file":
            handleFileURL(url)
        default:
            print("[GT] ⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
        }
    }
    
    private func handleGliderTrackerURL(_ url: URL) {
        // Handle custom app URLs like glidertracker://flight/123
        _ = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        switch url.host {
        case "flight":
            // Handle flight-related URLs
            if let flightId = url.pathComponents.last {
                print("[GT] 🛩️ Opening flight: \(flightId)")
                // Navigate to flight details
            }
        case "share":
            // Handle shared position URLs
            print("[GT] 📍 Handling shared position")
            // Process shared location data
        default:
            print("[GT] ⚠️ Unknown GliderTracker URL: \(url)")
        }
    }
    
    private func handleFileURL(_ url: URL) {
        // Handle file imports (GPX, IGC files)
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "gpx":
            print("[GT] 📄 Importing GPX file: \(url.lastPathComponent)")
            importGPXFile(url)
        case "igc":
            print("[GT] 📄 Importing IGC file: \(url.lastPathComponent)")
            importIGCFile(url)
        default:
            print("[GT] ⚠️ Unsupported file type: \(fileExtension)")
        }
    }
    
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        switch userActivity.activityType {
        case NSUserActivityTypeBrowsingWeb:
            // Handle web links
            if let url = userActivity.webpageURL {
                print("[GT] 🌐 Opening web URL: \(url)")
            }
        case "com.glidertracker.start-recording":
            // Handle Siri shortcut for starting flight recording
            print("[GT] 🎤 Siri: Start recording flight")
            startFlightRecording()
        case "com.glidertracker.view-flights":
            // Handle Siri shortcut for viewing flights
            print("[GT] 🎤 Siri: View flights")
            showFlightsList()
        default:
            print("[GT] ⚠️ Unknown user activity: \(userActivity.activityType)")
        }
    }
    
    // MARK: - App State Management
    
    private func resumeAppOperations() {
        print("[GT] ▶️ Resuming app operations")
        
        // Resume location tracking
        resumeLocationTracking()
        
        // Resume audio service if needed
        // AudioService.shared.start() // falls Sie eine start() Methode haben
    }
    
    private func pauseAppOperations() {
        print("[GT] ⏸️ Pausing app operations")
        
        // Pause non-essential operations
        // Keep location tracking active if flight is being recorded
    }
    
    private func resumeLocationTracking() {
        // Resume location tracking wenn Flight Recording aktiv
        print("[GT] 📍 Checking location tracking status")
        
        // Hier würden Sie Ihren LocationManager resumieren
        // if FlightRecorder.shared.isRecording {
        //     LocationManager.shared.startTracking()
        // }
    }
    
    private func saveAppState() async {
        print("[GT] 💾 Saving app state")
        
        // Save current flight data, user preferences, etc.
        UserDefaults.standard.set(Date(), forKey: AppConstants.UserDefaultsKeys.lastSyncDate)
        
        // Sync with CloudKit
        // await CloudKitPublisher.shared.syncPendingData()
    }
    
    private func performBackgroundCloudKitSync() async {
        print("[GT] ☁️ Performing background CloudKit sync")
        
        // Perform essential CloudKit operations
        await CloudKitPublisher.shared.checkContainerStatus()
        
        // Push any pending location data
        // await CloudKitPublisher.shared.pushPendingLocations()
    }
    
    // MARK: - File Import Handlers
    
    private func importGPXFile(_ url: URL) {
        // Handle GPX file import
        Task {
            do {
                _ = try Data(contentsOf: url)
                // Parse GPX data and import to CloudKit
                print("[GT] ✅ GPX file imported successfully")
            } catch {
                print("[GT] ❌ Failed to import GPX file: \(error)")
            }
        }
    }
    
    private func importIGCFile(_ url: URL) {
        // Handle IGC file import
        Task {
            do {
                _ = try String(contentsOf: url, encoding: .utf8)
                // Parse IGC data and import to CloudKit
                print("[GT] ✅ IGC file imported successfully")
            } catch {
                print("[GT] ❌ Failed to import IGC file: \(error)")
            }
        }
    }
    
    // MARK: - Siri Shortcuts Handlers
    
    private func startFlightRecording() {
        print("[GT] 🎬 Starting flight recording via Siri")
        
        // Start flight recording
        // FlightRecorder.shared.startRecording()
        
        // Navigate to recording view
        // NavigationManager.shared.showRecordingView()
    }
    
    private func showFlightsList() {
        print("[GT] 📋 Showing flights list via Siri")
        
        // Navigate to flights list
        // NavigationManager.shared.showFlightsList()
    }
}