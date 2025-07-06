//
//  CustomAlertViewController.swift
//  GliderTracker
//
//  Refactor 05 May 2025 – Remove duplicate types & modernise API
//  ----------------------------------------------------------------
//  ▸ Eliminates duplicate `GliderTrackerViewModel` and `ClimbActivityAttributes` definitions that clashed with main types.
//  ▸ Replaces deprecated ActivityKit calls with simple `UIAlertController` presentation.
//  ▸ Uses `AppConstants` instead of obsolete `Constants` struct.
//

import UIKit
import ActivityKit

/// A simple reusable alert wrapper.
final class CustomAlertViewController: UIViewController {

    private let message: String
    private let titleText: String

    init(title: String = "Warning", message: String) {
        self.titleText = title
        self.message   = message
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentAlert()
    }

    private func presentAlert() {
        let alert = UIAlertController(title: titleText, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) })
        present(alert, animated: true)
    }
}
