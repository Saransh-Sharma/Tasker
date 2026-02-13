//
//  AddTaskBackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

import UIKit

extension AddTaskViewController {
    // setupBackdrop() method removed to fix duplicate declaration

    func refreshBackdropGradientForCurrentTheme(deferredIfNeeded: Bool = true) {
        if backdropBackgroundImageView.superview != nil {
            backdropBackgroundImageView.frame = CGRect(
                x: 0,
                y: backdropNochImageView.bounds.height,
                width: backdropContainer.bounds.width,
                height: backdropContainer.bounds.height
            )
        }

        let bounds = backdropBackgroundImageView.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            guard deferredIfNeeded else { return }
            DispatchQueue.main.async { [weak self] in
                self?.refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
            }
            return
        }

        TaskerHeaderGradient.apply(
            to: backdropBackgroundImageView.layer,
            bounds: bounds,
            traits: traitCollection
        )
    }

    func refreshBackdropAppearanceForCurrentTheme(deferredIfNeeded: Bool = true) {
        let colors = todoColors
        view.backgroundColor = colors.accentPrimary.withAlphaComponent(0.05)
        backdropContainer.backgroundColor = colors.accentPrimary.withAlphaComponent(0.05)
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: deferredIfNeeded)
    }

    //MARK:- Setup Backdrop Background
    func setupBackdropBackground() {
        backdropBackgroundImageView.frame = CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)

        backdropContainer.addSubview(backdropBackgroundImageView)
        refreshBackdropAppearanceForCurrentTheme(deferredIfNeeded: false)
    }
}
