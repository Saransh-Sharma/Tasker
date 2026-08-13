import LifeBoardContracts
import LifeBoardDomain
import CoreData
import Foundation

/// The single resource boundary for LifeBoard's versioned Core Data model.
///
/// Keeping model lookup here makes the persistence code independent of the
/// application bundle. When this source is compiled by SwiftPM, resources are
/// resolved from `Bundle.module`; the app-target fallback preserves the current
/// runtime while the package product is adopted by every client target.
public enum LifeBoardPersistenceModel {
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
