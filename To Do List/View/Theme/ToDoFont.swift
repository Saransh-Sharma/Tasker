//
//  ToDoFont.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

class ToDoFont {

    //Mark: Util: set font
      func setFont(fontSize: CGFloat, fontweight: UIFont.Weight, fontDesign: UIFontDescriptor.SystemDesign) -> UIFont {
          
          // Here we get San Francisco with the desired weight
          let systemFont = UIFont.systemFont(ofSize: fontSize, weight: fontweight)
          
          // Will be SF Compact or standard SF in case of failure.
          let font: UIFont
          
          if let descriptor = systemFont.fontDescriptor.withDesign(fontDesign) {
              font = UIFont(descriptor: descriptor, size: fontSize)
          } else {
              font = systemFont
          }
          return font
      }
    
}
