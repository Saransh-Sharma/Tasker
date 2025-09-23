#!/usr/bin/env swift

//
//  MigrationScript.swift
//  Tasker
//
//  Script to help identify and migrate singleton usages
//  Run this to get a report of all files that need migration
//

import Foundation

// MARK: - Migration Mappings

struct MigrationMapping {
    let pattern: String
    let replacement: String
    let description: String
}

let taskManagerMappings = [
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.toggleTaskComplete",
        replacement: "performTaskOperation(.toggleComplete",
        description: "Toggle task completion"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.deleteTask",
        replacement: "performTaskOperation(.delete",
        description: "Delete task"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.getAllTasks",
        replacement: "viewModel?.todayTasks",
        description: "Get all tasks"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.saveContext()",
        replacement: "// Context save handled by repository",
        description: "Save context"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.addTask",
        replacement: "viewModel?.createTask",
        description: "Add new task"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.getUpcomingTasks",
        replacement: "viewModel?.upcomingTasks",
        description: "Get upcoming tasks"
    ),
    MigrationMapping(
        pattern: "TaskManager.sharedInstance.context",
        replacement: "// Direct context access not needed",
        description: "Context access"
    )
]

let projectManagerMappings = [
    MigrationMapping(
        pattern: "ProjectManager.sharedInstance.getAllProjects",
        replacement: "viewModel?.projects",
        description: "Get all projects"
    ),
    MigrationMapping(
        pattern: "ProjectManager.sharedInstance.displayedProjects",
        replacement: "viewModel?.projects",
        description: "Get displayed projects"
    ),
    MigrationMapping(
        pattern: "ProjectManager.sharedInstance.defaultProject",
        replacement: "\"Inbox\"",
        description: "Default project name"
    ),
    MigrationMapping(
        pattern: "ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults",
        replacement: "// Handled in setupCleanArchitecture()",
        description: "Fix missing project data"
    )
]

// MARK: - File Analysis

struct FileAnalysis {
    let path: String
    let singletonUsages: [String]
    let suggestedReplacements: [MigrationMapping]
}

func analyzeFile(at path: String) -> FileAnalysis? {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return nil
    }
    
    var usages: [String] = []
    var suggestions: [MigrationMapping] = []
    
    // Check for TaskManager usages
    for mapping in taskManagerMappings {
        if content.contains(mapping.pattern) {
            usages.append(mapping.pattern)
            suggestions.append(mapping)
        }
    }
    
    // Check for ProjectManager usages
    for mapping in projectManagerMappings {
        if content.contains(mapping.pattern) {
            usages.append(mapping.pattern)
            suggestions.append(mapping)
        }
    }
    
    if usages.isEmpty {
        return nil
    }
    
    return FileAnalysis(path: path, singletonUsages: usages, suggestedReplacements: suggestions)
}

// MARK: - Report Generation

func generateMigrationReport(for directory: String) {
    print("🔍 Scanning for singleton usages in: \(directory)")
    print("=" * 80)
    
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(atPath: directory)
    
    var filesToMigrate: [FileAnalysis] = []
    var totalUsages = 0
    
    while let element = enumerator?.nextObject() as? String {
        if element.hasSuffix(".swift") {
            let fullPath = "\(directory)/\(element)"
            
            // Skip migration files and Clean Architecture files
            if element.contains("Migration") || 
               element.contains("CleanArchitecture") ||
               element.contains("ViewModel") ||
               element.contains("UseCase") ||
               element.contains("Repository") {
                continue
            }
            
            if let analysis = analyzeFile(at: fullPath) {
                filesToMigrate.append(analysis)
                totalUsages += analysis.singletonUsages.count
            }
        }
    }
    
    // Generate report
    print("\n📊 MIGRATION REPORT")
    print("=" * 80)
    print("Total files to migrate: \(filesToMigrate.count)")
    print("Total singleton usages: \(totalUsages)")
    print()
    
    // Group by priority
    let highPriority = filesToMigrate.filter { 
        $0.path.contains("ViewController") || 
        $0.path.contains("AppDelegate") 
    }
    let mediumPriority = filesToMigrate.filter { 
        $0.path.contains("View") || 
        $0.path.contains("Service") 
    }
    let lowPriority = filesToMigrate.filter { file in
        !highPriority.contains { $0.path == file.path } &&
        !mediumPriority.contains { $0.path == file.path }
    }
    
    // Print high priority files
    if !highPriority.isEmpty {
        print("🔴 HIGH PRIORITY (Core ViewControllers)")
        print("-" * 40)
        for analysis in highPriority {
            printFileAnalysis(analysis)
        }
    }
    
    // Print medium priority files
    if !mediumPriority.isEmpty {
        print("\n🟡 MEDIUM PRIORITY (Views and Services)")
        print("-" * 40)
        for analysis in mediumPriority {
            printFileAnalysis(analysis)
        }
    }
    
    // Print low priority files
    if !lowPriority.isEmpty {
        print("\n🟢 LOW PRIORITY (Other files)")
        print("-" * 40)
        for analysis in lowPriority {
            printFileAnalysis(analysis)
        }
    }
    
    // Print summary
    print("\n📋 MIGRATION CHECKLIST")
    print("=" * 80)
    print("1. ✅ Update AppDelegate to use setupCleanArchitecture()")
    print("2. ✅ Add setupCleanArchitectureIfAvailable() to ViewControllers")
    print("3. ⏳ Replace singleton calls with ViewModel methods")
    print("4. ⏳ Test each migrated component")
    print("5. ⏳ Delete TaskManager.swift and ProjectManager.swift")
    print("6. ⏳ Remove migration adapters")
    print()
    print("Use MIGRATION_GUIDE.md for detailed instructions")
}

func printFileAnalysis(_ analysis: FileAnalysis) {
    let fileName = URL(fileURLWithPath: analysis.path).lastPathComponent
    print("\n📄 \(fileName)")
    print("   Path: \(analysis.path)")
    print("   Usages: \(analysis.singletonUsages.count)")
    
    for suggestion in analysis.suggestedReplacements {
        print("   • \(suggestion.description)")
        print("     OLD: \(suggestion.pattern)")
        print("     NEW: \(suggestion.replacement)")
    }
}

// MARK: - String Extension

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Main Execution

let currentDirectory = FileManager.default.currentDirectoryPath
let taskerDirectory = "\(currentDirectory)/To Do List"

if FileManager.default.fileExists(atPath: taskerDirectory) {
    generateMigrationReport(for: taskerDirectory)
} else {
    print("❌ Error: Could not find To Do List directory")
    print("   Please run this script from the Tasker project root directory")
}
