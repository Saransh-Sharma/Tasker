//
//  FluentUIFramework.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

public class FluentUIFramework: NSObject {
    @objc public static var bundle: Bundle { return Bundle(for: self) }
    @objc public static let resourceBundle: Bundle = {
        guard let url = bundle.resourceURL?.appendingPathComponent("FluentUIResources-ios.bundle", isDirectory: true), let bundle = Bundle(url: url) else {
            preconditionFailure("FluentUI resource bundle is not found")
        }
        return bundle
    }()

    @available(*, deprecated, message: "Non-fluent icons no longer supported. Setting this var no longer has any effect and it will be removed in a future update.")
    @objc public static var usesFluentIcons: Bool = true




  
}
