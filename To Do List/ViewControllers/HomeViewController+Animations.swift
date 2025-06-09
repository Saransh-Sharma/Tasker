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
        // Animate FluentUI table view reload
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            fluentTableView.reloadData()
        }, completion: nil)
    }
    
    func animateTableViewReloadSingleCell(at indexPath: IndexPath) {
        // Animate single cell reload in FluentUI table view
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.2, options: .transitionCrossDissolve, animations: {
            fluentTableView.reloadRows(at: [indexPath], with: .none)
        }, completion: nil)
    }
    
    func animateTableCellReload(at indexPath: IndexPath) {
        // Animate specific cell reload in FluentUI table view
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        if let cell = fluentTableView.cellForRow(at: indexPath) {
            UIView.transition(with: cell, duration: 0.2, options: .transitionCrossDissolve, animations: {
                // The cell content will be updated automatically
                fluentTableView.reloadRows(at: [indexPath], with: .none)
            }, completion: nil)
        }
    }
}
