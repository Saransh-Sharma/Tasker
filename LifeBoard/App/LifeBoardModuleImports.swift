// Re-export package-owned boundaries during the app-target migration. This
// keeps existing App-tier composition call sites source-compatible while the
// implementations compile only in their owning modules.
@_exported import LifeBoardCalendar
@_exported import LifeBoardDomain
@_exported import LifeBoardPersistence
@_exported import LifeBoardTranscription
@_exported import KnowledgeFeature
