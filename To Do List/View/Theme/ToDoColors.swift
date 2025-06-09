//
//  ToDoColors.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

class ToDoColors {
    
    //MARK: Theming: COLOURS
    //Original theme
    var backgroundColor = UIColor.systemGray5
    var primaryColor =  #colorLiteral(red: 0.5490196078, green: 0.5450980392, blue: 0.8196078431, alpha: 1)
    
    var primaryColorDarker = UIColor.black //UIColor.systemFill
    var secondaryAccentColor = #colorLiteral(red: 0.9824339747, green: 0.5298179388, blue: 0.176022768, alpha: 1)//UIColor.systemOrange
    var completeTaskSwipeColor = UIColor(red: 46/255.0, green: 204/255.0, blue: 113/255.0, alpha: 1.0)
    
    // Added missing properties for refactored code
    var darkModeColor = UIColor.black
    var primaryTextColor = UIColor.label
    var foregroundColor = UIColor.systemBackground
    
}
