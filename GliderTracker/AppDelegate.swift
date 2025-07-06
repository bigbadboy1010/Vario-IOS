//
//  AppDelegate.swift
//  GliderTracker
//
//  Updated for Multi-Container CloudKit Support - 2025-06-12
//  ---------------------------------------------------------
//  ▸ Supports both primary and legacy iCloud containers
//  ▸ Automatic CloudKit migration on first launch
//  ▸ Container status checking and validation
//  ▸ Robust error handling and logging
//  ▸ Background task management for CloudKit sync
//

import UIKit
import CloudKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Log app startup info
        logAppStartup()
        
        // Setup iCloud containers
        setupICloud()
        
        // Setup CloudKit migration (async)
        setupCloudKitMigration()
        
        // Setup audio service
        setupAudioService()
        
        return true
    }

    // MARK: – App Startup
    
    private func logAppStartup() {
        print("[GT] 🚀 GliderTracker starting...")
        print("[GT] 📱 Version: \(AppConstants.fullVersionString)")
        print("[GT] 🌍 Environment: \(AppConstants.cloudKitEnvironment)")
        print("[GT] 📦 Containers: \(AppConstants.containerInfo)")
        
        // Log migration status
        let migrationCompleted = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.migrationCompleted)
        print("[GT] 🔄 Migration status: \(migrationCompleted ? "✅ Completed" : "⏳ Pending")")
    }

    // MARK: – iCloud Container Setup
    
    private func setupICloud() {
        print("[GT] 🔍 Setting up iCloud containers...")
        
        // Check Primary Container
        let primaryContainerID = AppConstants.primaryiCloudContainerID
        if let primaryURL = FileManager.default.url(forUbiquityContainerIdentifier: primaryContainerID) {
            print("[GT] ✅ Primary iCloud container ready → \(primaryContainerID)")
            print("[GT] 📁 Primary URL: \(primaryURL)")
        } else {
            print("[GT] ❌ Primary iCloud container \(primaryContainerID) not available")
        }
        
        // Check Legacy Container
        let legacyContainerID = AppConstants.legacyiCloudContainerID
        if let legacyURL = FileManager.default.url(forUbiquityContainerIdentifier: legacyContainerID) {
            print("[GT] ✅ Legacy iCloud container ready → \(legacyContainerID)")
            print("[GT] 📁 Legacy URL: \(legacyURL)")
        } else {
            print("[GT] ⚠️ Legacy iCloud container \(legacyContainerID) not available")
        }
    }
    
    // MARK: – CloudKit Migration Setup
    
    private func setupCloudKitMigration() {
        Task {
            print("[GT] 🚀 Starting CloudKit setup...")
            
            // 1. Check container status
            await CloudKitPublisher.shared.checkContainerStatus()
            
            // 2. Perform migration if needed
            await CloudKitPublisher.shared.migrateIfNeeded()
            
            // 3. Mark setup as completed
            UserDefaults.standard.set(Date(), forKey: AppConstants.UserDefaultsKeys.lastSyncDate)
            
            print("[GT] ✅ CloudKit setup completed successfully")
        }
    }
    
    // MARK: – Audio Service Setup
    
    private func setupAudioService() {
        // AudioService initialisieren (falls noch nicht geschehen)
        _ = AudioService.shared
        print("[GT] 🎵 Audio service initialized")
    }

    // MARK: – UIScene
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    // MARK: – Background Tasks (für CloudKit Sync)
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[GT] 📱 App entered background")
        
        // Background task für CloudKit-Sync starten
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask(withName: "CloudKitSync") {
            // Cleanup wenn Zeit abläuft
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        Task {
            // Finale CloudKit-Synchronisation
            await CloudKitPublisher.shared.checkContainerStatus()
            
            // Background task beenden
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[GT] 📱 App entering foreground")
        
        // CloudKit status prüfen und ggf. sync resumieren
        Task {
            await CloudKitPublisher.shared.checkContainerStatus()
            
            // Check ob neue Migration nötig (falls App Update)
            let lastVersion = UserDefaults.standard.string(forKey: "LastAppVersion")
            if lastVersion != AppConstants.appVersion {
                print("[GT] 📱 App version changed: \(lastVersion ?? "nil") → \(AppConstants.appVersion)")
                UserDefaults.standard.set(AppConstants.appVersion, forKey: "LastAppVersion")
                
                // Könnte hier zusätzliche Migrations-Checks machen
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("[GT] 📱 App will terminate")
        
        // AudioService sauber stoppen
        AudioService.shared.stop()
        
        // Letzte CloudKit-Synchronisation
        // (Nur für kritische Daten, da Zeit begrenzt ist)
    }
    
    // MARK: – Memory Management
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("[GT] ⚠️ Memory warning received")
        // Hier könnten Sie Caches leeren oder nicht-kritische Daten freigeben
    }
}

