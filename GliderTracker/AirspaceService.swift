import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - Notification

extension Notification.Name {
    /// Wird gefeuert, sobald neue Overlays vorliegen (Main‑Thread)
    static let airspacesDidUpdate = Notification.Name("airspacesDidUpdate")
}

// MARK: - Models

/// OpenAIP Core API Response Struktur
struct OpenAIPResponse: Codable {
    let limit: Int
    let totalCount: Int
    let totalPages: Int
    let nextPage: Int?
    let page: Int
    let items: [AirspaceItem]
}

/// Ein einzelner Airspace-Eintrag von der OpenAIP Core API
struct AirspaceItem: Codable, Identifiable {
    let _id: String
    let name: String
    let geometry: Geometry
    let country: String?
    let upperLimit: Limit?
    let lowerLimit: Limit?
    let type: Int?
    let icaoClass: Int?
    
    // Computed property für Identifiable
    var id: String { _id }
    
    struct Geometry: Codable {
        let type: String                   // "Polygon"
        let coordinates: [[[Double]]]      // [ [ [lon, lat], … ] ] (GeoJSON‑Standard)
    }
    
    struct Limit: Codable {
        let value: Double
        let unit: Int
        let referenceDatum: Int
    }
}

// MARK: - Service

@MainActor
final class AirspaceService {
    private let debouncer = Debouncer(delay: 1.0)

    static let shared = AirspaceService()
    private init() {}

    // Öffentliche MapKit‑Overlays, die die ViewController nutzen
    private(set) var overlays: [MKOverlay] = []

    // MARK: - Service Configuration
    
    /*
     Airspace Update-Strategie:
     - API Requests: Alle 30 Minuten (da sich Airspaces sehr selten ändern)
     - UI Updates: Alle 20 Minuten (weniger häufig als API, um UI-Performance zu schonen)
     - Mindestdistanz: 15km (größerer Radius für Airspace-Regionen)
     
     Rationale: Airspaces ändern sich normalerweise nur bei:
     - Offiziellen NOTAM-Updates
     - Änderungen der Luftfahrtbehörden
     - Saisonalen Anpassungen
     */

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    private var cancellables = Set<AnyCancellable>()
    
    // Rate limiting protection - Airspaces ändern sich sehr selten
    private var lastRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 1800.0 // 30 Minuten zwischen API-Requests
    
    // 🔧 Region Caching um doppelte Requests zu vermeiden
    private var lastRequestedRegion: CLCircularRegion?
    private let minimumDistanceForNewRequest: CLLocationDistance = 15000 // 15km (größere Distanz für Airspaces)
    
    // 🔧 FIX: Overlay-Caching um unnötige Updates zu vermeiden
    private var lastOverlayCount: Int = -1
    private var lastUpdateTime: Date = .distantPast
    private let minimumUpdateInterval: TimeInterval = 1200.0 // 20 Minuten zwischen UI-Updates
    
    // OpenAIP API Key - sollte idealerweise aus einer Config-Datei oder Environment Variable kommen
    private let apiKey = "c00232952896543cc6d56e349b1f9cef"
    
    // ✅ AKTUALISIERTE BASE URL
    private let baseURL = "https://api.core.openaip.net/api/airspaces"

    /// Lädt Lufträume innerhalb der gewünschten Region (Radius in m) und liefert sie als Publisher zurück.
    func fetchAirspace(in region: CLCircularRegion) -> AnyPublisher<[AirspaceItem], Error> {
        // 🔧 Prüfe ob wir bereits Daten für eine ähnliche Region haben
        if let lastRegion = lastRequestedRegion {
            let distance = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                .distance(from: CLLocation(latitude: lastRegion.center.latitude, longitude: lastRegion.center.longitude))
            
            if distance < minimumDistanceForNewRequest {
                print("⏭️ Skipping request - too close to last region (distance: \(Int(distance))m)")
                // 🔧 FIX: Signalisiere dass dies ein Skip war, nicht echte leere Daten
                return Fail(error: AirspaceServiceError.skipDueToDistance).eraseToAnyPublisher()
            }
        }
        
        // Rate limiting check
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let delay = minimumRequestInterval - timeSinceLastRequest
            print("⏱️ Rate limiting: waiting \(String(format: "%.1f", delay/60))min")
            return Just(())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                .flatMap { [weak self] _ -> AnyPublisher<[AirspaceItem], Error> in
                    guard let self else {
                        return Fail(error: URLError(.cancelled)).eraseToAnyPublisher()
                    }
                    return self.performAirspaceRequest(in: region)
                }
                .eraseToAnyPublisher()
        }
        
        return performAirspaceRequest(in: region)
    }
    
    private func performAirspaceRequest(in region: CLCircularRegion) -> AnyPublisher<[AirspaceItem], Error> {
        lastRequestTime = Date()
        lastRequestedRegion = region
        
        guard let url = makeURL(for: region) else {
            print("❌ Failed to create URL for region: \(region)")
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    throw URLError(.badServerResponse)
                }
                
                print("📡 OpenAIP Response: HTTP \(http.statusCode)")
                
                // Erweiterte Fehlerbehandlung für besseres Debugging
                switch http.statusCode {
                case 200..<300:
                    print("✅ Successful response with \(data.count) bytes")
                    return data
                case 400:
                    print("❌ Bad Request (400) - Check API parameters")
                    throw URLError(.badURL)
                case 401:
                    print("❌ Unauthorized (401) - Check API key")
                    throw URLError(.userAuthenticationRequired)
                case 403:
                    print("❌ Forbidden (403) - API key permissions")
                    throw URLError(.noPermissionsToReadFile)
                case 404:
                    print("❌ Not Found (404) - Endpoint may have changed")
                    throw URLError(.fileDoesNotExist)
                case 429:
                    print("❌ Rate Limit Exceeded (429)")
                    throw URLError(.timedOut)
                case 500..<600:
                    print("❌ Server Error (\(http.statusCode))")
                    throw URLError(.badServerResponse)
                default:
                    print("❌ Unexpected HTTP \(http.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseString.prefix(500))")
                    }
                    throw URLError(.badServerResponse)
                }
            }
            .decode(type: OpenAIPResponse.self, decoder: decoder)
            .map { response in
                print("✅ Decoded OpenAIP response: page \(response.page)/\(response.totalPages), \(response.items.count) items")
                return response.items
            }
            .catch { error -> AnyPublisher<[AirspaceItem], Error> in
                print("❌ AirspaceService Error: \(error)")
                
                // Spezifische Fehlerbehandlung
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        print("🌐 No internet connection")
                    case .timedOut:
                        print("⏰ Request timed out")
                    case .cannotFindHost:
                        print("🔍 Cannot find host - DNS issue?")
                    case .cannotConnectToHost:
                        print("🔌 Cannot connect to host")
                    default:
                        print("🌐 Network error: \(urlError.localizedDescription)")
                    }
                } else if let decodingError = error as? DecodingError {
                    print("📦 JSON decoding error: \(decodingError)")
                }
                
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 🔧 FIXED: Startet eine neue Abfrage, konvertiert die Items direkt in `MKOverlay`s
    /// und feuert NUR bei WIRKLICHEN Änderungen `Notification.Name.airspacesDidUpdate`.
    func refresh(in region: CLCircularRegion) {
        print("🔄 Refreshing airspace data for region: \(region.center)")
        print("📍 Radius: \(String(format: "%.1f", region.radius / 1000))km")
        
        // 🔧 FIX: Prüfe Update-Interval
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        if timeSinceLastUpdate < minimumUpdateInterval {
            print("⏭️ Skipping update - too frequent (last update \(String(format: "%.1f", timeSinceLastUpdate/60))min ago)")
            return
        }
        
        fetchAirspace(in: region)
            .map { items in
                print("✅ Received \(items.count) airspace items")
                let validOverlays = items.compactMap(Self.makeOverlay(from:))
                print("🗺️ Created \(validOverlays.count) valid overlays")
                return validOverlays
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("✅ Airspace data refresh completed")
                case .failure(let error):
                    // 🔧 FIX: Unterscheide zwischen echten Fehlern und Skips
                    if case AirspaceServiceError.skipDueToDistance = error {
                        print("⏭️ Skipped due to distance - no notification needed")
                        return // Keine Notification bei Skip!
                    }
                    print("❌ Airspace data refresh failed: \(error)")
                }
            }, receiveValue: { [weak self] overlays in
                // 🔧 FIX: Use strong self pattern to avoid warning
                guard let strongSelf = self else { return }
                
                // 🔧 FIX: Nur Notification senden wenn sich wirklich was geändert hat
                let overlayCount = overlays.count
                
                if overlayCount != strongSelf.lastOverlayCount {
                    print("📊 Overlay count changed: \(strongSelf.lastOverlayCount) → \(overlayCount)")
                    
                    strongSelf.overlays = overlays
                    strongSelf.lastOverlayCount = overlayCount
                    strongSelf.lastUpdateTime = now
                    
                    print("📡 Posted airspacesDidUpdate notification with \(overlays.count) overlays")
                    NotificationCenter.default.post(name: .airspacesDidUpdate, object: strongSelf)
                } else {
                    print("📊 No change in overlay count (\(overlayCount)) - skipping notification")
                }
            })
            .store(in: &cancellables)
    }

    /// Bequeme Überladung: erlaubt einen einfachen CLLocation‑Punkt zu übergeben.
    /// `radius` ist in Metern (Default = 100 km).
    func refresh(for location: CLLocation, radius: CLLocationDistance = 30_000) {
        let region = CLCircularRegion(center: location.coordinate, radius: radius, identifier: "current")
        refresh(in: region)
    }

    // MARK: Helper

    private func makeURL(for region: CLCircularRegion) -> URL? {
        // ✅ KORRIGIERTE URL-STRUKTUR - Verwendet die neue OpenAIP Core API
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            .init(name: "lat",    value: String(format: "%.6f", region.center.latitude)),
            .init(name: "lon",    value: String(format: "%.6f", region.center.longitude)),
            .init(name: "radius", value: String(format: "%.1f", region.radius / 1_000)), // km
            .init(name: "apiKey", value: apiKey) // ✅ API Key als Parameter
        ]
        
        let url = components?.url
        print("🌐 OpenAIP Request URL: \(url?.absoluteString ?? "nil")")
        return url
    }

    private static func makeOverlay(from item: AirspaceItem) -> MKOverlay? {
        guard item.geometry.type.lowercased() == "polygon",
              let firstRing = item.geometry.coordinates.first else {
            print("⚠️ Skipping item with invalid geometry: \(item.id)")
            return nil
        }

        guard !firstRing.isEmpty else {
            print("⚠️ Skipping item with empty coordinates: \(item.id)")
            return nil
        }

        let coords = firstRing.compactMap { coordArray -> CLLocationCoordinate2D? in
            guard coordArray.count >= 2 else { return nil }
            let lat = coordArray[1]
            let lon = coordArray[0]
            
            // Validiere Koordinaten
            guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
                print("⚠️ Invalid coordinates: lat=\(lat), lon=\(lon)")
                return nil
            }
            
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        guard coords.count >= 3 else {
            print("⚠️ Insufficient valid coordinates for polygon: \(item.id)")
            return nil
        }

        let polygon = MKPolygon(coordinates: coords, count: coords.count)
        polygon.title = item.name
        
        print("✅ Created overlay for \(item.id): \(item.name)")
        return polygon
    }
}

// MARK: - Custom Error Types

enum AirspaceServiceError: Error {
    case skipDueToDistance
    case skipDueToRateLimit
    case noDataChanged
}

// MARK: - Testing & Debugging

extension AirspaceService {
    
    /// Test-Funktion um die API-Verbindung zu prüfen
    func testConnection() {
        let testLocation = CLLocation(latitude: 47.3445, longitude: 9.6225) // Dornbirn
        print("🧪 Testing API connection...")
        
        fetchAirspace(in: CLCircularRegion(center: testLocation.coordinate, radius: 10_000, identifier: "test"))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("✅ API connection test successful")
                case .failure(let error):
                    print("❌ API connection test failed: \(error)")
                }
            }, receiveValue: { items in
                print("🎯 Test returned \(items.count) items")
            })
            .store(in: &cancellables)
    }
    
    /// Debug-Info über aktuelle Konfiguration
    func printDebugInfo() {
        print("🔧 AirspaceService Debug Info:")
        print("   Base URL: \(baseURL)")
        print("   API Key: \(apiKey.prefix(8))...")
        print("   Current overlays: \(overlays.count)")
        print("   Last request: \(lastRequestTime)")
        print("   Last overlay count: \(lastOverlayCount)")
        print("   Last update: \(lastUpdateTime)")
        print("   Min request interval: \(minimumRequestInterval/60) min")
        print("   Min update interval: \(minimumUpdateInterval/60) min")
        print("   Min distance for new request: \(minimumDistanceForNewRequest/1000) km")
    }
    
    /// 🔧 FIX: Manuelle Reset-Funktion für Debugging
    func resetCache() {
        print("🔄 Resetting AirspaceService cache...")
        lastRequestedRegion = nil
        lastOverlayCount = -1
        lastUpdateTime = .distantPast
        lastRequestTime = .distantPast
        overlays.removeAll()
        print("✅ Cache reset completed")
    }
}
