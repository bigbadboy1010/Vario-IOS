//
//  VarioWatch_Watch_AppUITestsLaunchTests.swift
//  VarioWatch Watch AppUITests
//
//  Created by François De Lattre on 27.01.24.
//  Copyright © 2024 @Miggu69. All rights reserved.
//

import XCTest

final class VarioWatch_Watch_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
