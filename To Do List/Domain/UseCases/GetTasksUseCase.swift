import Foundation

/// Use case protocol for retrieving various collections of tasks
protocol GetTasksUseCase {
    func getMorningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void)
    func getEveningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void)
    func getUpcomingTasks(completion: @escaping ([TaskData]) -> Void)
    func getTasksForInbox(on date: Date, completion: @escaping ([TaskData]) -> Void)
    func getTasksForProject(_ projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void)
    func getOpenTasksForProject(_ projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void)
    func getOpenTasksForAllCustomProjects(on date: Date, completion: @escaping ([TaskData]) -> Void)
}
