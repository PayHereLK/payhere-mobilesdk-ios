//
//  PrimaryTheme.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2025-11-24.
//  Copyright © 2025 PayHere. All rights reserved.
//

import UIKit

public extension UIColor {
    enum PrimaryTheme {
        static let ViewBackground :UIColor = .phColor(named: "Primary/View Background")
        static let Clickable      :UIColor = .phColor(named: "Primary/Clickable")
        static let TitleText      :UIColor = .phColor(named: "Primary/Title Text")
        static let Black          :UIColor = .phColor(named: "Primary/Black")
        static let White          :UIColor = .phColor(named: "Primary/White")
        static let Red            :UIColor = .phColor(named: "Primary/Red")
        static let CellSelected   :UIColor = .phColor(named: "Primary/CellSelected")
        static let CardBackground :UIColor = .phColor(named: "Primary/Card Background")
    }
}

extension UIColor {
    static func phColor(named name: String) -> UIColor {
        guard let color = UIColor(
            named: name,
            in: Bundle.payHereBundle,
            compatibleWith: nil
        ) else {
            assertionFailure("Missing color asset: \(name)")
            return .systemBlue
        }
        return color
    }
}
