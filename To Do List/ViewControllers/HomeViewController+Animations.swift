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
        let dynamicDistance = calculateRevealDistance()
        revealDistance = dynamicDistance // Store for moveUp method
        
        print("move: CAL SHOW - down: \(dynamicDistance) (dynamic calculation)")
        view.center.y += dynamicDistance
    }
    
    func moveUp_toHideCal(view: UIView) {
        isCalDown = false
        print("move: CAL HIDE - up: \(revealDistance) (stored distance)")
        view.center.y -= revealDistance // Use stored distance to ensure exact return
    }
    
    // MARK: - Charts Animations
    
    func moveDown_revealCharts(view: UIView) {
        isChartsDown = true
        let dynamicDistance = calculateChartRevealDistance()
        chartRevealDistance = dynamicDistance // Store for moveUp method
        
        print("move: CHARTS SHOW - down: \(dynamicDistance) (dynamic calculation)")
        view.center.y += dynamicDistance
    }
    
    func moveDown_revealChartsKeepCal(view: UIView) {
        isChartsDown = true
        // Calculate additional distance needed when calendar is already shown
        let baseChartDistance = calculateChartRevealDistance()
        let calendarDistance = revealDistance // Use stored calendar distance
        let additionalDistance = max(0, baseChartDistance - calendarDistance)
        chartRevealDistance = additionalDistance // Store for moveUp method
        
        print("move: CHARTS SHOW, CAL SHOW - down additional: \(additionalDistance) (dynamic calculation)")
        view.center.y += additionalDistance
    }
    
    func moveUp_hideCharts(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE - up: \(chartRevealDistance) (stored distance)")
        view.center.y -= chartRevealDistance // Use stored distance to ensure exact return
    }
    
    func moveUp_hideChartsKeepCal(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE, CAL SHOW - up: \(chartRevealDistance) (stored distance)")
        view.center.y -= chartRevealDistance // Use stored distance to ensure exact return
    }
    
//    // MARK: - TableView Animations
//    
    func animateTableViewReload() {
        // Animate FluentUI table view reload
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.2, options: .transitionFlipFromBottom, animations: {
            fluentTableView.reloadData()
        }, completion: nil)
    }
    
    func animateTableViewReloadSingleCell(at indexPath: IndexPath) {
        // Animate single cell reload in FluentUI table view
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.2, options: .transitionFlipFromRight, animations: {
            fluentTableView.reloadRows(at: [indexPath], with: .none)
        }, completion: nil)
    }
    
    func animateTableCellReload(at indexPath: IndexPath) {
        // Animate specific cell reload in FluentUI table view
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        if let cell = fluentTableView.cellForRow(at: indexPath) {
            UIView.transition(with: cell, duration: 0.2, options: .transitionFlipFromRight, animations: {
                // The cell content will be updated automatically
                fluentTableView.reloadRows(at: [indexPath], with: .none)
            }, completion: nil)
        }
    }
}
