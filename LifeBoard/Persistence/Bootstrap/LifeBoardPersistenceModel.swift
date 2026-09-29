import LifeBoardContracts
import LifeBoardDomain
import CoreData
import Foundation

/// Every model version shipped by LifeBoard, in migration order.
///
/// Filenames describe the feature that introduced a schema change and are not
/// chronologically sortable. Keep this registry append-only: removing or
/// reordering a case can strand an existing store during an app update.
public enum PersistenceModelVersion: String, CaseIterable, Sendable {
    case initial = "TaskModelV3"
    case gamification = "TaskModelV3_Gamification"
    case habits = "TaskModelV3_Habits"
    case weeklyPlanning = "TaskModelV3_WeeklyPlanning"
    case timeline = "TaskModelV3_Timeline"
    case taskIcons = "TaskModelV3_TaskIcons"
    case lifeOSFoundation = "TaskModelV3_LifeOSFoundation"
    case adaptiveHome = "TaskModelV3_AdaptiveHome"
    case pulseProgress = "TaskModelV3_PulseProgress"
    case trackers = "TaskModelV3_Trackers"
    case journal = "TaskModelV3_Journal"
    case knowledgeNotes = "TaskModelV3_KnowledgeNotes"
    case planningCore = "TaskModelV3_PlanningCore"
    case trackFoundations = "TaskModelV3_TrackFoundations"
    case journalParity = "TaskModelV3_JournalParity"
    case wellnessCore = "TaskModelV3_WellnessCore"
    case nutrition = "TaskModelV3_Nutrition"
    case lifeMoments = "TaskModelV3_LifeMoments"
    case healthPrivacy = "TaskModelV3_HealthPrivacy"
    case notesPro = "TaskModelV3_NotesPro"
    case notesCompletion = "TaskModelV3_NotesCompletion"
    case taskStartDay = "TaskModelV3_TaskStartDay"
    case behaviorFlagship = "TaskModelV3_BehaviorFlagship"
    case evaDecisionLoops = "TaskModelV3_EvaDecisionLoops"
    case habitProgress = "TaskModelV3_HabitProgress"

    public static let current: Self = .habitProgress

    public var sourceModelName: String { "\(rawValue).xcdatamodel" }
    public var compiledModelName: String { "\(rawValue).mom" }
}

/// The single resource boundary for LifeBoard's versioned Core Data model.
///
/// Keeping model lookup here makes the persistence code independent of the
/// application bundle. When this source is compiled by SwiftPM, resources are
/// resolved from `Bundle.module`; the app-target fallback preserves the current
/// runtime while the package product is adopted by every client target.
public enum LifeBoardPersistenceModel {
    public static let orderedVersions = PersistenceModelVersion.allCases

    public enum ModelError: LocalizedError {
        case resourceNotFound
        case unreadableModel(URL)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound:
                return "Unable to locate TaskModelV3.momd"
            case .unreadableModel(let url):
                return "Unable to load the Core Data model at \(url.path)"
            }
        }
    }

    /// The compiled model URL, if the package/application contains it.
    public static var modelURL: URL? {
        resourceBundle.url(forResource: "TaskModelV3", withExtension: "momd")
    }

    /// Loads the current version of the shipped managed-object model.
    public static func makeModel() throws -> NSManagedObjectModel {
        guard let modelURL else {
            throw ModelError.resourceNotFound
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw ModelError.unreadableModel(modelURL)
        }
        return model
    }

    /// Constructs a CloudKit-capable container with the package-owned model.
    public static func makeCloudKitContainer(
        name: String = "TaskModelV3"
    ) throws -> NSPersistentCloudKitContainer {
        NSPersistentCloudKitContainer(name: name, managedObjectModel: try makeModel())
    }

    /// Constructs a plain container with the package-owned model.
    public static func makeContainer(
        name: String = "TaskModelV3"
    ) throws -> NSPersistentContainer {
        NSPersistentContainer(name: name, managedObjectModel: try makeModel())
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
            Bundle.module
        #else
            Bundle.main
        #endif
    }
}
