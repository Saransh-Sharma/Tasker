import Foundation

enum ProjectExecutionModeProjection {
    static func coalescing(
        _ modes: [(UUID, ProjectExecutionMode)]
    ) -> [UUID: ProjectExecutionMode] {
        var result: [UUID: ProjectExecutionMode] = [:]
        var duplicateCount = 0
        for (projectID, mode) in modes {
            guard let existingMode = result[projectID] else {
                result[projectID] = mode
                continue
            }

            duplicateCount += 1
            // Preserve the restrictive interpretation while identity repair
            // resolves a transient Core Data/CloudKit collision.
            if mode == .sequential || existingMode == .sequential {
                result[projectID] = .sequential
            }
        }
        if duplicateCount > 0 {
            logWarning(
                event: "planning_project_identity_collision",
                message: "Planning projection safely coalesced duplicate project identities",
                fields: ["duplicate_count": String(duplicateCount)]
            )
        }
        return result
    }
}
