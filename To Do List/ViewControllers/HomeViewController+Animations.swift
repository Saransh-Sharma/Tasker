//
//  HomeViewController+Animations.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import ViewAnimator

extension HomeViewController {
    
    // MARK: - Basic Animations
    
    func moveRight(view: UIView) {
        view.center.x += 300
    }
    
    func moveLeft(view: UIView) {
        view.center.x -= 300
    }
    
    // MARK: - Calendar Animations
    
    func moveDown_revealJustCal(view: UIView) {
        isCalDown = true
        print("move: CAL SHOW - down: \(UIScreen.main.bounds.height/4)")
        view.center.y += UIScreen.main.bounds.height/4
    }
    
    func moveUp_toHideCal(view: UIView) {
        isCalDown = false
        print("move: CAL HIDE - down: \(UIScreen.main.bounds.height/4)")
        view.center.y -= UIScreen.main.bounds.height/4
    }
    
    // MARK: - Charts Animations
    
    func moveDown_revealCharts(view: UIView) {
        isChartsDown = true
        print("move: CHARTS SHOW - down: \(UIScreen.main.bounds.height/2)")
        view.center.y += UIScreen.main.bounds.height/2
    }
    
    func moveDown_revealChartsKeepCal(view: UIView) {
        isChartsDown = true
        print("move: CHARTS SHOW, CAL SHOW - down some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)")
        view.center.y += UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12
    }
    
    func moveUp_hideCharts(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE - up some: \(UIScreen.main.bounds.height/2)")
        view.center.y -= UIScreen.main.bounds.height/2
    }
    
    func moveUp_hideChartsKeepCal(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE, CAL SHOW - up some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)")
        view.center.y -= UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12
    }
    
//    // MARK: - TableView Animations
//    
    func animateTableViewReload() {
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       reversed: true,
                       initialAlpha: 0.0,
                       finalAlpha: 1.0,
                       delay: 0,
                       animationInterval: 0.05,
                       duration: shouldAnimateCells ? 0.5 : 0,
                       options: .curveEaseInOut,
                       completion: nil)
    }
    
    func animateTableViewReloadSingleCell(cellAtIndexPathRow: Int) {
        let indexPath = IndexPath(row: cellAtIndexPathRow, section: 0)
        tableView.reloadRows(at: [indexPath], with: .fade)
        
        if let cell = tableView.cellForRow(at: indexPath) {
            let animation = AnimationType.from(direction: .bottom, offset: 30.0)
            UIView.animate(views: [cell],
                           animations: [animation],
                           reversed: false,
                           initialAlpha: 0.0,
                           finalAlpha: 1.0,
                           delay: 0,
                           animationInterval: 0.05,
                           duration: 0.5,
                           options: .curveEaseInOut,
                           completion: nil)
        }
    }
    
    func animateTableCellReload() {
        let fromAnimation = AnimationType.vector(CGVector(dx: 30, dy: 0))
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [fromAnimation],
                       reversed: false,
                       initialAlpha: 0.2,
                       finalAlpha: 1.0,
                       delay: 0.0,
                       animationInterval: 0.03)
    }
}
