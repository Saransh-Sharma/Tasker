#!/usr/bin/env swift
import Foundation
import CoreData

struct BenchmarkSnapshot: Codable {
    struct Percentiles: Codable {
        let p50_ms: Double
        let p95_ms: Double
        let p99_ms: Double
    }

    struct Metrics: Codable {
        let home: Percentiles
        let project: Percentiles
        let search: Percentiles
    }

    let generatedAt: String
    let seed: UInt64
    let tasks: Int
    let occurrences: Int
    let metrics: Metrics
}

struct LCG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        Int(next() % UInt64(max(1, upperBound)))
    }
}

func percentile(_ values: [Double], p: Double) -> Double {
    guard values.isEmpty == false else { return 0 }
    let sorted = values.sorted()
    let rank = Int((Double(sorted.count - 1) * p).rounded())
    return sorted[min(max(0, rank), sorted.count - 1)]
}

func parseIntArg(_ name: String, defaultValue: Int) -> Int {
    guard
        let index = CommandLine.arguments.firstIndex(of: name),
        CommandLine.arguments.count > index + 1,
        let value = Int(CommandLine.arguments[index + 1])
    else {
        return defaultValue
    }
    return value
}

func parseStringArg(_ name: String, defaultValue: String) -> String {
    guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.count > index + 1 else {
        return defaultValue
    }
    return CommandLine.arguments[index + 1]
}

func runProcess(_ launchPath: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw NSError(
            domain: "perf_seed_v3",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "Process failed: \(launchPath) \(arguments.joined(separator: " "))"]
        )
    }
}

func makeContainer(repoRoot: URL) throws -> NSPersistentContainer {
    let sourceModel = repoRoot.appendingPathComponent("To Do List/TaskModelV3.xcdatamodeld")
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let compiledModel = tempDir.appendingPathComponent("TaskModelV3-benchmark-\(UUID().uuidString).momd")
    let momc = "/Applications/Xcode.app/Contents/Developer/usr/bin/momc"
    try runProcess(momc, [sourceModel.path, compiledModel.path])

    guard let model = NSManagedObjectModel(contentsOf: compiledModel) else {
        throw NSError(domain: "perf_seed_v3", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load compiled model"])
    }

    let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]

    var loadError: Error?
    let semaphore = DispatchSemaphore(value: 0)
    container.loadPersistentStores { _, error in
        loadError = error
        semaphore.signal()
    }
    semaphore.wait()
    if let loadError {
        throw loadError
    }
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    return container
}

func seedTasks(
    container: NSPersistentContainer,
    taskCount: Int,
    seed: UInt64
) throws -> [UUID] {
    let context = container.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    let calendar = Calendar(identifier: .gregorian)
    let now = Date()
    var rng = LCG(seed: seed)
    let projectIDs: [UUID] = (0..<40).map { _ in UUID() }

    try context.performAndWait {
        for idx in 0..<taskCount {
            let projectID = projectIDs[rng.nextInt(projectIDs.count)]
            let dueDate = calendar.date(byAdding: .day, value: rng.nextInt(120) - 30, to: now) ?? now
            let updatedAt = calendar.date(byAdding: .minute, value: rng.nextInt(60 * 24 * 30), to: now) ?? now
            let isComplete = rng.nextInt(100) < 38
            let priorityRaw = Int32([1, 2, 3, 4][rng.nextInt(4)])
            let title = "Task \(idx) alpha\(rng.nextInt(100)) beta\(rng.nextInt(100))"
            let id = UUID()

            let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            object.setValue(id, forKey: "id")
            object.setValue(id, forKey: "taskID")
            object.setValue(projectID, forKey: "projectID")
            object.setValue(title, forKey: "title")
            object.setValue("Notes \(idx)", forKey: "notes")
            object.setValue("active", forKey: "status")
            object.setValue(priorityRaw, forKey: "priority")
            object.setValue(Int32(1), forKey: "taskType")
            object.setValue(isComplete, forKey: "isComplete")
            object.setValue(isComplete ? updatedAt : nil, forKey: "dateCompleted")
            object.setValue(now, forKey: "dateAdded")
            object.setValue(now, forKey: "createdAt")
            object.setValue(updatedAt, forKey: "updatedAt")
            object.setValue(dueDate, forKey: "dueDate")
            object.setValue(false, forKey: "isEveningTask")
            object.setValue("medium", forKey: "energy")
            object.setValue("general", forKey: "category")
            object.setValue("anywhere", forKey: "context")

            if idx % 1000 == 0 {
                try context.save()
                context.reset()
            }
        }
        if context.hasChanges {
            try context.save()
        }
    }

    return projectIDs
}

func measure(_ block: () -> Void) -> Double {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let end = CFAbsoluteTimeGetCurrent()
    return (end - start) * 1_000
}

func runBenchmark(
    container: NSPersistentContainer,
    projectIDs: [UUID],
    iterations: Int
) throws -> BenchmarkSnapshot.Metrics {
    let context = container.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    let calendar = Calendar(identifier: .gregorian)
    let now = Date()

    var homeSamples: [Double] = []
    var projectSamples: [Double] = []
    var searchSamples: [Double] = []
    homeSamples.reserveCapacity(iterations)
    projectSamples.reserveCapacity(iterations)
    searchSamples.reserveCapacity(iterations)

    for i in 0..<iterations {
        let anchor = calendar.date(byAdding: .day, value: (i % 14) - 7, to: now) ?? now
        let startOfDay = calendar.startOfDay(for: anchor)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? anchor
        let selectedProject = projectIDs[i % projectIDs.count]
        let token = "alpha\(i % 50)"

        let homeMs = measure {
            context.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
                request.predicate = NSPredicate(format: "dueDate <= %@", endOfDay as NSDate)
                request.sortDescriptors = [
                    NSSortDescriptor(key: "dueDate", ascending: true),
                    NSSortDescriptor(key: "taskID", ascending: true)
                ]
                request.fetchLimit = 400
                _ = try? context.fetch(request)
            }
        }
        homeSamples.append(homeMs)

        let projectMs = measure {
            context.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
                request.predicate = NSPredicate(format: "projectID == %@", selectedProject as CVarArg)
                request.sortDescriptors = [
                    NSSortDescriptor(key: "updatedAt", ascending: false),
                    NSSortDescriptor(key: "taskID", ascending: true)
                ]
                request.fetchLimit = 300
                _ = try? context.fetch(request)
            }
        }
        projectSamples.append(projectMs)

        let searchMs = measure {
            context.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "title CONTAINS[cd] %@", token),
                    NSPredicate(format: "notes CONTAINS[cd] %@", token)
                ])
                request.sortDescriptors = [
                    NSSortDescriptor(key: "title", ascending: true),
                    NSSortDescriptor(key: "taskID", ascending: true)
                ]
                request.fetchLimit = 200
                _ = try? context.fetch(request)
            }
        }
        searchSamples.append(searchMs)
    }

    return .init(
        home: .init(
            p50_ms: percentile(homeSamples, p: 0.50),
            p95_ms: percentile(homeSamples, p: 0.95),
            p99_ms: percentile(homeSamples, p: 0.99)
        ),
        project: .init(
            p50_ms: percentile(projectSamples, p: 0.50),
            p95_ms: percentile(projectSamples, p: 0.95),
            p99_ms: percentile(projectSamples, p: 0.99)
        ),
        search: .init(
            p50_ms: percentile(searchSamples, p: 0.50),
            p95_ms: percentile(searchSamples, p: 0.95),
            p99_ms: percentile(searchSamples, p: 0.99)
        )
    )
}

let taskCount = max(1, parseIntArg("--tasks", defaultValue: 20_000))
let occurrenceCount = max(1, parseIntArg("--occurrences", defaultValue: 200_000))
let iterations = max(30, parseIntArg("--iterations", defaultValue: 120))
let outputPath = parseStringArg("--output", defaultValue: "build/benchmarks/v2_readmodel.json")
let seed: UInt64 = 1_337_2026

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let container = try makeContainer(repoRoot: cwd)
let projectIDs = try seedTasks(container: container, taskCount: taskCount, seed: seed)
let metrics = try runBenchmark(container: container, projectIDs: projectIDs, iterations: iterations)

let snapshot = BenchmarkSnapshot(
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    seed: seed,
    tasks: taskCount,
    occurrences: occurrenceCount,
    metrics: metrics
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try encoder.encode(snapshot).write(to: outputURL)
print("Wrote benchmark snapshot to \(outputURL.path)")
