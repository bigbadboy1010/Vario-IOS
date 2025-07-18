
//
//  ViewController+MapDelegate.swift
//
//  Auto‑generated by ChatGPT on 2025-07-04
//
import MapKit
import UIKit

extension ViewController: MKMapViewDelegate {
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let pilotAnnotation = annotation as? PilotAnnotation else { return nil }

        let identifier = "PilotAnnotationView"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view?.canShowCallout = true
        } else {
            view?.annotation = annotation
        }

        switch pilotAnnotation.role {
        case .me:
            view?.markerTintColor = .systemBlue  // you
        case .other:
            view?.markerTintColor = .systemRed   // others
        }

        return view
    }
}
