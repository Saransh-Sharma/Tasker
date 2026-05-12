import Foundation
import CoreData

struct LifeAreaRepairReport {
    let scanned: Int
    let normalized: Int
    let merged: Int
    let deleted: Int
    let duplicateGroups: Int
    let repointedProjects: Int
    let repointedTasks: Int
    let repointedHabits: Int
    let canonicalIDsByNormalizedName: [String: UUID]
}

enum LifeAreaIdentityRepair {
    static let defaultLifeAreaName = "General"

    /// Executes normalizedName.
    static func normalizedName(_ name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultLifeAreaName : trimmed
    }

    /// Executes normalizedNameKey.
    static func normalizedNameKey(_ name: String?) -> String {
        normalizedName(name).lowercased()
    }

    /// Executes repair.
    static func repair(in context: NSManagedObjectContext) throws -> LifeAreaRepairReport {
        let lifeAreas = try fetchObjects(entityName: "LifeArea", in: context)
        let projects = try fetchObjects(entityName: "Project", in: context)
        let tasks = try fetchObjects(entityName: "TaskDefinition", in: context)
        let habits = try fetchObjects(entityName: "HabitDefinition", in: context)

        var normalizedChanges = 0
        for area in lifeAreas {
            if area.value(forKey: "id") as? UUID == nil {
                area.setValue(UUID(), forKey: "id")
                normalizedChanges += 1
            }

            let currentName = area.value(forKey: "name") as? String
            let normalized = normalizedName(currentName)
            if currentName != normalized {
                area.setValue(normalized, forKey: "name")
                normalizedChanges += 1
            }
        }

        var inboundCounts: [UUID: Int] = [:]
        countInboundReferences(from: projects, into: &inboundCounts)
        countInboundReferences(from: tasks, into: &inboundCounts)
        countInboundReferences(from: habits, into: &inboundCounts)

        let grouped = Dictionary(grouping: lifeAreas) { normalizedNameKey($0.value(forKey: "name") as? String) }
        let duplicateGroups = grouped.values.filter { $0.count > 1 }.count

        var canonicalByName: [String: NSManagedObject] = [:]
        var duplicatesToDelete: [NSManagedObject] = []
        var repointedProjects = 0
        var repointedTasks = 0
        var repointedHabits = 0

        let sortedGroupKeys = grouped.keys.sorted()
        for key in sortedGroupKeys {
            guard let group = grouped[key], group.isEmpty == false else { continue }
            let canonical = selectCanonicalLifeArea(from: group, inboundCounts: inboundCounts)
            canonicalByName[key] = canonical

            let canonicalID = ensureLifeAreaID(on: canonical)
            mergeMissingVisualMetadata(into: canonical, from: group)

            for duplicate in group where duplicate.objectID != canonical.objectID {
                let duplicateID = ensureLifeAreaID(on: duplicate)

                repointedProjects += repointReferences(
                    in: projects,
                    sourceID: duplicateID,
                    targetID: canonicalID,
                    relationshipKey: "lifeAreaRef",
                    canonicalLifeArea: canonical
                )
                repointedTasks += repointReferences(
                    in: tasks,
                    sourceID: duplicateID,
                    targetID: canonicalID,
                    relationshipKey: nil,
                    canonicalLifeArea: nil
                )
                repointedHabits += repointReferences(
                    in: habits,
                    sourceID: duplicateID,
                    targetID: canonicalID,
                    relationshipKey: "lifeAreaRef",
                    canonicalLifeArea: canonical
                )

                duplicatesToDelete.append(duplicate)
            }
        }

        for duplicate in duplicatesToDelete {
            context.delete(duplicate)
        }

        let canonicalIDsByNormalizedName = canonicalByName.reduce(into: [String: UUID]()) { partialResult, entry in
            partialResult[entry.key] = ensureLifeAreaID(on: entry.value)
        }

        return LifeAreaRepairReport(
            scanned: lifeAreas.count,
            normalized: normalizedChanges,
            merged: duplicatesToDelete.count,
            deleted: duplicatesToDelete.count,
            duplicateGroups: duplicateGroups,
            repointedProjects: repointedProjects,
            repointedTasks: repointedTasks,
            repointedHabits: repointedHabits,
            canonicalIDsByNormalizedName: canonicalIDsByNormalizedName
        )
    }

    /// Executes fetchObjects.
    private static func fetchObjects(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
            return []
        }
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.returnsObjectsAsFaults = false
        return try context.fetch(request)
    }

    /// Executes ensureLifeAreaID.
    private static func ensureLifeAreaID(on object: NSManagedObject) -> UUID {
        if let id = object.value(forKey: "id") as? UUID {
            return id
        }
        let generated = UUID()
        object.setValue(generated, forKey: "id")
        return generated
    }

    /// Executes countInboundReferences.
    private static func countInboundReferences(from objects: [NSManagedObject], into counts: inout [UUID: Int]) {
        for object in objects {
            guard object.entity.attributesByName["lifeAreaID"] != nil else { continue }
            guard let lifeAreaID = object.value(forKey: "lifeAreaID") as? UUID else { continue }
            counts[lifeAreaID, default: 0] += 1
        }
    }

    /// Executes selectCanonicalLifeArea.
    private static func selectCanonicalLifeArea(
        from group: [NSManagedObject],
        inboundCounts: [UUID: Int]
    ) -> NSManagedObject {
        group.min { lhs, rhs in
            compare(lhs: lhs, rhs: rhs, inboundCounts: inboundCounts)
        } ?? group[0]
    }

    /// Executes compare.
    private static func compare(
        lhs: NSManagedObject,
        rhs: NSManagedObject,
        inboundCounts: [UUID: Int]
    ) -> Bool {
        let lhsArchived = lhs.value(forKey: "isArchived") as? Bool ?? false
        let rhsArchived = rhs.value(forKey: "isArchived") as? Bool ?? false
        if lhsArchived != rhsArchived {
            return lhsArchived == false
        }

        let lhsID = ensureLifeAreaID(on: lhs)
        let rhsID = ensureLifeAreaID(on: rhs)
        let lhsInbound = inboundCounts[lhsID] ?? 0
        let rhsInbound = inboundCounts[rhsID] ?? 0
        if lhsInbound != rhsInbound {
            return lhsInbound > rhsInbound
        }

        let lhsCreated = createdDate(of: lhs)
        let rhsCreated = createdDate(of: rhs)
        if lhsCreated != rhsCreated {
            return lhsCreated < rhsCreated
        }

        return lhsID.uuidString.localizedCaseInsensitiveCompare(rhsID.uuidString) == .orderedAscending
    }

    /// Executes createdDate.
    private static func createdDate(of object: NSManagedObject) -> Date {
        if let created = object.value(forKey: "createdAt") as? Date {
            return created
        }
        if let updated = object.value(forKey: "updatedAt") as? Date {
            return updated
        }
        return .distantFuture
    }

    /// Executes mergeMissingVisualMetadata.
    private static func mergeMissingVisualMetadata(
        into canonical: NSManagedObject,
        from group: [NSManagedObject]
    ) {
        if isBlank(canonical.value(forKey: "color") as? String),
           let candidate = firstNonBlankValue(forKey: "color", from: group) {
            canonical.setValue(candidate, forKey: "color")
        }

        if isBlank(canonical.value(forKey: "icon") as? String),
           let candidate = firstNonBlankValue(forKey: "icon", from: group) {
            canonical.setValue(candidate, forKey: "icon")
        }
    }

    /// Executes firstNonBlankValue.
    private static func firstNonBlankValue(forKey key: String, from objects: [NSManagedObject]) -> String? {
        for object in objects {
            if let raw = object.value(forKey: key) as? String, isBlank(raw) == false {
                return raw
            }
        }
        return nil
    }

    /// Executes isBlank.
    private static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    /// Executes repointReferences.
    private static func repointReferences(
        in objects: [NSManagedObject],
        sourceID: UUID,
        targetID: UUID,
        relationshipKey: String?,
        canonicalLifeArea: NSManagedObject?
    ) -> Int {
        var updated = 0
        for object in objects {
            guard object.entity.attributesByName["lifeAreaID"] != nil else { continue }
            guard let current = object.value(forKey: "lifeAreaID") as? UUID else { continue }
            guard current == sourceID else { continue }

            object.setValue(targetID, forKey: "lifeAreaID")
            if let relationshipKey,
               object.entity.relationshipsByName[relationshipKey] != nil,
               let canonicalLifeArea {
                object.setValue(canonicalLifeArea, forKey: relationshipKey)
            }
            updated += 1
        }
        return updated
    }
}
