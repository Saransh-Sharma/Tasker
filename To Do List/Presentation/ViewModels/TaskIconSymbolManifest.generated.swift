import Foundation

enum TaskIconSymbolManifest {
    static let options: [TaskIconOption] = {
        guard let url = Bundle.main.url(
            forResource: "TaskIconSymbolManifest.generated",
            withExtension: "json"
        ) else {
            logError(
                event: "task_icon_manifest_missing",
                message: "Bundled task icon manifest JSON is missing"
            )
            return []
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return try JSONDecoder().decode([TaskIconOption].self, from: data)
        } catch {
            logError(
                event: "task_icon_manifest_decode_failed",
                message: "Failed to decode bundled task icon manifest",
                fields: ["error": String(describing: error)]
            )
            return []
        }
    }()
}
