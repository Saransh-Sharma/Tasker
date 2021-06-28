//
//  RippleDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 24/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import MaterialComponents.MaterialRipple

class TinyPieChartRippleDelegate: NSObject, MDCRippleTouchControllerDelegate {
    
    func rippleTouchController(_ rippleTouchController: MDCRippleTouchController,
                               insert rippleView: MDCRippleView,
                               into view: UIView) {
        view.insertSubview(rippleView, at: 0)
    }
    
    func rippleTouchController(_ rippleTouchController: MDCRippleTouchController,
                               didProcessRippleView rippleView: MDCRippleView,
                               atTouchLocation location: CGPoint) {
    }
}

class DateViewRippleDelegate: NSObject, MDCRippleTouchControllerDelegate {
    
    //  func rippleTouchController(_ rippleTouchController: MDCRippleTouchController, shouldProcessRippleTouchesAtTouchLocation location: CGPoint) -> Bool {
    //    // Determine if we want to display the ripple
    //    return exampleView.frame.contains(location)
    //  }
    
    func rippleTouchController(_ rippleTouchController: MDCRippleTouchController,
                               insert rippleView: MDCRippleView,
                               into view: UIView) {
        print("ripple checkpoint A1")
        view.insertSubview(rippleView, at: 0)
    }
    
    func rippleTouchController(_ rippleTouchController: MDCRippleTouchController,
                               didProcessRippleView rippleView: MDCRippleView,
                               atTouchLocation location: CGPoint) {
        print("Did process ripple view!")
    }
    
    
    
}

