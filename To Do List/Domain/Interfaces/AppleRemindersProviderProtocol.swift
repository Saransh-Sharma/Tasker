import Foundation

public struct AppleReminderItemSnapshot: Codable, Equatable, Hashable {
    public let itemID: String
    public let calendarID: String
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var completionDate: Date?
    public var isCompleted: Bool
    public var priority: Int
    public var urlString: String?
    public var alarmDates: [Date]
    public var lastModifiedAt: Date?
    public var payloadData: Data?

    /// Initializes a new instance.
    public init(
        itemID: String,
        calendarID: String,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        completionDate: Date? = nil,
        isCompleted: Bool = false,
        priority: Int = 0,
        urlString: String? = nil,
        alarmDates: [Date] = [],
        lastModifiedAt: Date? = nil,
        payloadData: Data? = nil
    ) {
        self.itemID = itemID
        self.calendarID = calendarID
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.completionDate = completionDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.urlString = urlString
        self.alarmDates = alarmDates
        self.lastModifiedAt = lastModifiedAt
        self.payloadData = payloadData
    }
}

public struct AppleReminderListSnapshot: Codable, Equatable, Hashable {
    public let listID: String
    public let title: String

    /// Initializes a new instance.
    public init(listID: String, title: String) {
        self.listID = listID
        self.title = title
    }
}

public protocol AppleRemindersProviderProtocol {
    /// Executes requestAccess.
    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void)
    /// Executes fetchLists.
    func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void)
    /// Executes fetchReminders.
    func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void)
    /// Executes upsertReminder.
    func upsertReminder(listID: String, snapshot: AppleReminderItemSnapshot, completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void)
    /// Executes deleteReminder.
    func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void)
}
