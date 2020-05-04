//
//  FancyUI.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import TableViewReloadAnimation

class FancyUI {
    
    func reloadTable(tableView: UITableView)  {
        tableView.reloadData(
                   with: .simple(duration: 0.75, direction: .rotation3D(type: .ironMan),
                   constantDelay: 0))
    }
}
