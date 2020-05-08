//
//  TintTextField.swift
//  To Do List
//
//  Created by Saransh Sharma on 07/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

class TintTextField: UITextField {

    var tintedClearImage: UIImage?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
      self.setupTintColor()
    }

    override init(frame: CGRect) {
      super.init(frame: frame)
      self.setupTintColor()
    }

    func setupTintColor() {
      self.borderStyle = UITextField.BorderStyle.roundedRect
      self.layer.cornerRadius = 8.0
      self.layer.masksToBounds = true
      self.layer.borderColor = self.tintColor.cgColor
      self.layer.borderWidth = 1.5
      self.backgroundColor = .clear
      self.textColor = self.tintColor
    }

   override func layoutSubviews() {
       super.layoutSubviews()
       self.tintClearImage()
   }

   private func tintClearImage() {
       for view in subviews {
           if view is UIButton {
               let button = view as! UIButton
               if let image = button.image(for: .highlighted) {
                   if self.tintedClearImage == nil {
                       tintedClearImage = self.tintImage(image: image, color: self.tintColor)
                   }
                   button.setImage(self.tintedClearImage, for: .normal)
                   button.setImage(self.tintedClearImage, for: .highlighted)
               }
           }
       }
   }

   private func tintImage(image: UIImage, color: UIColor) -> UIImage {
       let size = image.size

       UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
       let context = UIGraphicsGetCurrentContext()
       image.draw(at: .zero, blendMode: CGBlendMode.normal, alpha: 1.0)

       context?.setFillColor(color.cgColor)
       context?.setBlendMode(CGBlendMode.sourceIn)
       context?.setAlpha(1.0)

       let rect = CGRect(x: CGPoint.zero.x, y: CGPoint.zero.y, width: image.size.width, height: image.size.height)
       UIGraphicsGetCurrentContext()?.fill(rect)
       let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
       UIGraphicsEndImageContext()

       return tintedImage ?? UIImage()
   }
}
