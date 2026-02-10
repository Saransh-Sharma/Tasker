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
    
    // MARK: - Calendar Animations (Spring-based)

    func moveDown_revealJustCal(view: UIView) {
        isCalDown = true
        let dynamicDistance = calculateRevealDistance()
        revealDistance = dynamicDistance

        print("move: CAL SHOW - down: \(dynamicDistance) (spring animation)")
        let targetY = view.center.y + dynamicDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            view.center.y = targetY
        }
    }

    func moveUp_toHideCal(view: UIView) {
        isCalDown = false
        print("move: CAL HIDE - up: \(revealDistance) (spring animation)")
        let targetY = view.center.y - revealDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            view.center.y = targetY
        }
    }

    // MARK: - Charts Animations (Spring-based)

    func moveDown_revealCharts(view: UIView) {
        isChartsDown = true
        let dynamicDistance = calculateChartRevealDistance()
        chartRevealDistance = dynamicDistance

        print("move: CHARTS SHOW - down: \(dynamicDistance) (spring animation)")
        let targetY = view.center.y + dynamicDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiGentle) {
            view.center.y = targetY
        }
    }

    func moveDown_revealChartsKeepCal(view: UIView) {
        isChartsDown = true
        let baseChartDistance = calculateChartRevealDistance()
        let calendarDistance = revealDistance
        let additionalDistance = max(0, baseChartDistance - calendarDistance)
        chartRevealDistance = additionalDistance

        print("move: CHARTS SHOW, CAL SHOW - down additional: \(additionalDistance) (spring animation)")
        let targetY = view.center.y + additionalDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiGentle) {
            view.center.y = targetY
        }
    }

    func moveUp_hideCharts(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE - up: \(chartRevealDistance) (spring animation)")
        let targetY = view.center.y - chartRevealDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            view.center.y = targetY
        }
    }

    func moveUp_hideChartsKeepCal(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE, CAL SHOW - up: \(chartRevealDistance) (spring animation)")
        let targetY = view.center.y - chartRevealDistance
        UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
            view.center.y = targetY
        }
    }
    
//    // MARK: - TableView Animations
//    
    func animateTableViewReload() {
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            fluentTableView.reloadData()
        }, completion: nil)
    }

    func animateTableViewReloadSingleCell(at indexPath: IndexPath) {
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        UIView.transition(with: fluentTableView, duration: 0.25, options: .transitionCrossDissolve, animations: {
            fluentTableView.reloadRows(at: [indexPath], with: .none)
        }, completion: nil)
    }

    func animateTableCellReload(at indexPath: IndexPath) {
        guard let fluentTableView = fluentToDoTableViewController?.tableView else { return }
        if let cell = fluentTableView.cellForRow(at: indexPath) {
            UIView.transition(with: cell, duration: 0.25, options: .transitionCrossDissolve, animations: {
                fluentTableView.reloadRows(at: [indexPath], with: .none)
            }, completion: nil)
        }
    }
}
