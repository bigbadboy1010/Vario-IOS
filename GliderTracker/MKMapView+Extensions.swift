//
//  MKMapView+Extensions.swift
//  GliderTracker
//
//  Build-fix 05 May 2025 – MKMapSize.zero & API tidy-up
//
//  ▸ Replaces non-existent `MKMapSize.zero` with `MKMapSize(width:0, height:0)`.
//  ▸ Keeps convenience zoom / fit helpers and overlay replacement.
//

import MapKit
import UIKit

extension MKMapView {

    // MARK: – Zoom helpers
    func zoom(by scale: Double, animated: Bool = true) {
        guard scale != 1 else { return }
        var region = self.region
        region.span.latitudeDelta   *= scale
        region.span.longitudeDelta  *= scale
        setRegion(regionThatFits(region), animated: animated)
    }

    func zoomIn(animated: Bool = true)  { zoom(by: 0.5, animated: animated) }
    func zoomOut(animated: Bool = true) { zoom(by: 2.0, animated: animated) }

    func zoom(to coordinate: CLLocationCoordinate2D,
              distance: CLLocationDistance,
              animated: Bool = true) {
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: distance,
                                        longitudinalMeters: distance)
        setRegion(regionThatFits(region), animated: animated)
    }

    // MARK: – Fit route
    func fit(coordinates: [CLLocationCoordinate2D],
             edgePadding: UIEdgeInsets = UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
             animated: Bool = true) {
        guard !coordinates.isEmpty else { return }
        var mapRect = MKMapRect.null
        for coord in coordinates {
            let point = MKMapPoint(coord)
            let rect  = MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0))
            mapRect   = mapRect.union(rect)
        }
        setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: animated)
    }

    // MARK: – Overlay handling
    @discardableResult
    func replaceRouteOverlay(with coordinates: [CLLocationCoordinate2D],
                             strokeColor: UIColor = .systemRed,
                             lineWidth: CGFloat = 3,
                             animated: Bool = false) -> MKPolyline? {
        overlays.compactMap { $0 as? MKPolyline }.forEach(removeOverlay)
        guard coordinates.count >= 2 else { return nil }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        addOverlay(polyline, level: .aboveRoads)
        if animated { fit(coordinates: coordinates, animated: true) }
        return polyline
    }
}
