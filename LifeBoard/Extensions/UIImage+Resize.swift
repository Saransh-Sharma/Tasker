//
//  UIImage+Resize.swift
//  To Do List
//
//  Created for Tasker App
//  Copyright © 2025 saransh1337. All rights reserved.
//

import UIKit

extension UIImage {
    /// Resizes the image to the specified size while maintaining quality
    /// - Parameter size: The target size for the image
    /// - Returns: A resized UIImage, or nil if resizing fails
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Resizes the image to fit within the specified size while maintaining aspect ratio
    /// - Parameter size: The maximum size for the image
    /// - Returns: A resized UIImage that fits within the bounds, or nil if resizing fails
    func resizedToFit(within size: CGSize) -> UIImage? {
        let aspectWidth = size.width / self.size.width
        let aspectHeight = size.height / self.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let newSize = CGSize(
            width: self.size.width * aspectRatio,
            height: self.size.height * aspectRatio
        )
        
        return resized(to: newSize)
    }
}
