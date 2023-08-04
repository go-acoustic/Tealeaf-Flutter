//
//  TealeafApplication.swift
//  Runner
//
//  Created by Tealeaf.
//

import Foundation
import UIKit
import Tealeaf

class TealeafApplication:  UIApplication {
    override func sendEvent(_ event: UIEvent) {
        TLFApplicationHelper.sharedInstance().send(event)
        super.sendEvent(event)
    }

    override func sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        TLFApplicationHelper.sharedInstance().sendAction(action, to: target, from: sender, for: event)
        return super.sendAction(action, to: target, from: sender, for: event)
    }
}
