//
//  TaskManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import CoreData 

class TaskManager {
    //Singleton
    static let sharedInstance = TaskManager()
    
    private var tasks = [Task]()
    let context: NSManagedObjectContext!
    
    func fetchTasks() {
        
        
        
    }
    
    // MARK: Init
    
    private init() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        context = appDelegate.persistentContainer.viewContext
    }
    
}
