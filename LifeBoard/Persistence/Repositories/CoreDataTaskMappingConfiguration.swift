import LifeBoardContracts
import LifeBoardDomain
import Foundation

/// Owns the persisted switch for the snapshot-based task mapper.
///
/// Keeping the key in Persistence prevents repositories from reaching into
/// the App-tier feature-flag namespace while preserving the existing default.
public enum CoreDataTaskMappingConfiguration {
    public static let defaultsKey = "feature.ipad.perf.coredata_mapping_snapshot_v3"

    public static var isSnapshotMappingEnabled: Bool {
        get { value(in: .standard) }
        set { setValue(newValue, in: .standard) }
    }

    public static func value(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? true
    }

    public static func setValue(_ value: Bool, in defaults: UserDefaults) {
        defaults.set(value, forKey: defaultsKey)
    }
}
