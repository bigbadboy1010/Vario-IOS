import Foundation
import CarPlay

@available(iOS 17.0, *)
final class CarPlayManager: NSObject, CPTemplateApplicationSceneDelegate {
    static let shared = CarPlayManager()
    private override init() { super.init() }
    // Implement required CPTemplateApplicationSceneDelegate methods if needed
    
    // 🆕 Add this function so PilotFetcher compiles
    func updateNearby(callsigns: [String]) {
        print("🚗 CarPlay: Update nearby pilot callsigns: \(callsigns)")
        // TODO: Integrate with CarPlay UI if needed
    }
}

final class CarPlayManagerLegacy {
    static let shared = CarPlayManagerLegacy()
    private init() {}
}
