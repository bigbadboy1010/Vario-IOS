//  CarPlayManager.swift
//  GliderTracker
//
//  CarPlay integration – Driving Task (iOS 17) with graceful fallback for older head‑units.
//  No entitlement yet required; add capability once Apple approves.
//

import Foundation
import CarPlay
import CoreLocation

final class CarPlayManager: NSObject {

    static let shared = CarPlayManager()
    private override init() {}

    fileprivate weak var interfaceController: CPTemplateApplicationInterfaceController?
}

extension CarPlayManager: CPTemplateApplicationSceneDelegate {

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPTemplateApplicationInterfaceController) {
        self.interfaceController = interfaceController

        // Root template
        let root: CPTemplate
        if #available(iOS 17.0, *) {
            let cfg = CPGaugeConfiguration(fillFraction: 0.5,
                                           leadingLabel: "−5 m/s",
                                           trailingLabel: "+5 m/s")
            root = CPGaugeTemplate(title: "Variometer", detail: "m/s", gaugeConfigurations: [cfg])
        } else {
            let item = CPListItem(text: "Variometer: 0.0 m/s", detailText: nil)
            root = CPListTemplate(title: "Variometer", sections: [CPListSection(items: [item])])
        }

        // Secondary list template (nearby gliders)
        let emptyItem = CPListItem(text: "No gliders yet", detailText: nil)
        let nearby = CPListTemplate(title: "Nearby Gliders", sections: [CPListSection(items: [emptyItem])])

        interfaceController.setRootTemplate(root, animated: false) {
            interfaceController.pushTemplate(nearby, animated: true)
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPTemplateApplicationInterfaceController,
                                  fromCarPlayInterfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }
}

// MARK: – Public Update API
extension CarPlayManager {

    /// Update variometer value (−10…+10 m/s)
    func updateVario(climbRate: Double) {
        guard let ic = interfaceController else { return }
        if #available(iOS 17.0, *),
           let gauge = ic.rootTemplate as? CPGaugeTemplate,
           let cfg  = gauge.gaugeConfigurations.first {
            let clamp = max(-10, min(10, climbRate))
            cfg.fillFraction = (clamp + 10) / 20
            ic.reloadTemplate(gauge, animated: false)
        } else if let list = ic.rootTemplate as? CPListTemplate,
                  let first = list.sections.first?.items.first {
            first.text = String(format: "Variometer: %.1f m/s", climbRate)
            list.updateSections(list.sections)
        }
    }

    /// Replace list of nearby callsigns
    func updateNearby(callsigns: [String]) {
        guard let ic = interfaceController else { return }
        let items = callsigns.map { CPListItem(text: $0, detailText: nil) }
        let listTemplates = ic.templates.compactMap { $0 as? CPListTemplate }
        // assume second template is nearby list
        if listTemplates.count > 1 {
            listTemplates[1].updateSections([CPListSection(items: items)])
        }
    }
}
