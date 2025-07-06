//
//  PilotAnnotation.swift
//  GliderTracker
//
//  Created by ChatGPT on 05/06/2025.
//  Simple MKAnnotation wrapper for displaying other pilots.
//  🆕 Updated to show pilot names and additional info.
//
import Foundation
import MapKit

final class PilotAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    
    // 🆕 Added title and subtitle for displaying pilot info
    var title: String?
    var subtitle: String?
    
    // 🆕 Store the full pilot position for additional info
    let pilotPosition: PilotPosition?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.pilotPosition = nil
        super.init()
    }
    
    // 🆕 New initializer with pilot position
    init(pilotPosition: PilotPosition) {
        self.coordinate = pilotPosition.coordinate
        self.pilotPosition = pilotPosition
        self.title = pilotPosition.name ?? "Unknown Pilot"
        self.subtitle = "\(pilotPosition.altitudeString) • \(pilotPosition.verticalSpeedString) • \(pilotPosition.timeAgoString)"
        super.init()
    }
    
    // 🆕 Update annotation with new pilot data
    func update(with pilotPosition: PilotPosition) {
        self.coordinate = pilotPosition.coordinate
        self.title = pilotPosition.name ?? "Unknown Pilot"
        self.subtitle = "\(pilotPosition.altitudeString) • \(pilotPosition.verticalSpeedString) • \(pilotPosition.timeAgoString)"
    }
}
