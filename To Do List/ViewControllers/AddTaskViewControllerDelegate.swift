//
//  AddTaskViewControllerDelegate.swift
//  To Do List
//
//  Created by Saransh Sharma on 03/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation

protocol AddTaskViewControllerDelegate: AnyObject {
    func didAddTask(_ task: NTask)
}
