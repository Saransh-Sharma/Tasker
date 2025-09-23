// LGTaskListVariations.swift
// Specialized task list view controllers - Phase 4 Implementation
// Today, Upcoming, Weekly, and Completed task views

import UIKit
import CoreData

// MARK: - Today Tasks View Controller

class LGTodayViewController: LGBaseListViewController {
    
    override func viewDidLoad() {
        setupViewModel()
        super.viewDidLoad()
    }
    
    override func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGTodayViewModel(context: context)
    }
    
    override func configureTitle() {
        titleLabel.text = "Today"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        subtitleLabel.text = formatter.string(from: Date())
    }
    
    override func showFilterOptions() {
        let alert = UIAlertController(title: "Filter Today's Tasks", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "All Tasks", style: .default) { _ in
            (self.viewModel as? LGTodayViewModel)?.setFilter(.all)
        })
        
        alert.addAction(UIAlertAction(title: "Pending Only", style: .default) { _ in
            (self.viewModel as? LGTodayViewModel)?.setFilter(.pending)
        })
        
        alert.addAction(UIAlertAction(title: "High Priority", style: .default) { _ in
            (self.viewModel as? LGTodayViewModel)?.setFilter(.highPriority)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
            popover.sourceRect = filterButton.bounds
        }
        
        present(alert, animated: true)
    }
}

class LGTodayViewModel: LGTaskListViewModel {
    
    enum Filter {
        case all, pending, highPriority
    }
    
    private var currentFilter: Filter = .all
    
    override func createFetchRequest() -> NSFetchRequest<NTask> {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isComplete", ascending: true),
            NSSortDescriptor(key: "taskPriority", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        return request
    }
    
    override func filterTasks(_ tasks: [NTask]) -> [NTask] {
        switch currentFilter {
        case .all:
            return tasks
        case .pending:
            return tasks.filter { !$0.isComplete }
        case .highPriority:
            return tasks.filter { $0.taskPriority <= 2 } // High and Highest priority
        }
    }
    
    func setFilter(_ filter: Filter) {
        currentFilter = filter
        refreshTasks()
    }
}

// MARK: - Upcoming Tasks View Controller

class LGUpcomingViewController: LGBaseListViewController {
    
    override func viewDidLoad() {
        setupViewModel()
        super.viewDidLoad()
    }
    
    override func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGUpcomingViewModel(context: context)
    }
    
    override func configureTitle() {
        titleLabel.text = "Upcoming"
        subtitleLabel.text = "Next 7 days"
    }
    
    override func showFilterOptions() {
        let alert = UIAlertController(title: "Filter Upcoming Tasks", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Next 7 Days", style: .default) { _ in
            (self.viewModel as? LGUpcomingViewModel)?.setTimeRange(.week)
        })
        
        alert.addAction(UIAlertAction(title: "Next 30 Days", style: .default) { _ in
            (self.viewModel as? LGUpcomingViewModel)?.setTimeRange(.month)
        })
        
        alert.addAction(UIAlertAction(title: "All Future", style: .default) { _ in
            (self.viewModel as? LGUpcomingViewModel)?.setTimeRange(.all)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
            popover.sourceRect = filterButton.bounds
        }
        
        present(alert, animated: true)
    }
}

class LGUpcomingViewModel: LGTaskListViewModel {
    
    enum TimeRange {
        case week, month, all
    }
    
    private var currentTimeRange: TimeRange = .week
    
    override func createFetchRequest() -> NSFetchRequest<NTask> {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        
        var endDate: Date
        switch currentTimeRange {
        case .week:
            endDate = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow)!
        case .month:
            endDate = calendar.date(byAdding: .day, value: 30, to: startOfTomorrow)!
        case .all:
            endDate = calendar.date(byAdding: .year, value: 10, to: startOfTomorrow)!
        }
        
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO", startOfTomorrow as NSDate, endDate as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "taskPriority", ascending: true)
        ]
        
        return request
    }
    
    func setTimeRange(_ range: TimeRange) {
        currentTimeRange = range
        refreshTasks()
    }
}

// MARK: - Weekly View Controller

class LGWeeklyViewController: LGBaseListViewController {
    
    override func viewDidLoad() {
        setupViewModel()
        super.viewDidLoad()
    }
    
    override func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGWeeklyViewModel(context: context)
    }
    
    override func configureTitle() {
        titleLabel.text = "This Week"
        
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        subtitleLabel.text = "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }
    
    override func updateTaskList(_ tasks: [NTask]) {
        // Group tasks by day for weekly view
        let groupedTasks = Dictionary(grouping: tasks) { task -> String in
            guard let dueDate = task.dueDate else { return "No Date" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: dueDate)
        }
        
        // Clear existing content
        taskCards.forEach { $0.removeFromSuperview() }
        taskCards.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Show empty state if no tasks
        emptyStateView.isHidden = !tasks.isEmpty
        if tasks.isEmpty {
            emptyStateView.morphGlass(to: .shimmerPulse, config: .subtle)
            return
        }
        
        // Create day sections
        let sortedDays = groupedTasks.keys.sorted { day1, day2 in
            // Sort by date
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            let date1 = formatter.date(from: day1) ?? Date.distantPast
            let date2 = formatter.date(from: day2) ?? Date.distantPast
            return date1 < date2
        }
        
        for (dayIndex, day) in sortedDays.enumerated() {
            let dayTasks = groupedTasks[day] ?? []
            
            // Create day header
            let dayHeader = createDayHeader(day: day, taskCount: dayTasks.count)
            stackView.addArrangedSubview(dayHeader)
            
            // Create task cards for this day
            for (taskIndex, task) in dayTasks.enumerated() {
                let taskCard = createTaskCard(for: task)
                taskCards.append(taskCard)
                stackView.addArrangedSubview(taskCard)
                
                taskCard.snp.makeConstraints { make in
                    make.height.equalTo(LGDevice.isIPad ? 100 : 80)
                }
                
                // Animate entrance
                taskCard.alpha = 0
                taskCard.transform = CGAffineTransform(translationX: 0, y: 20)
                
                let delay = TimeInterval(dayIndex) * 0.1 + TimeInterval(taskIndex) * 0.05
                UIView.animate(withDuration: 0.3, delay: delay, options: .curveEaseOut) {
                    taskCard.alpha = 1
                    taskCard.transform = .identity
                }
            }
        }
    }
    
    private func createDayHeader(day: String, taskCount: Int) -> UIView {
        let headerView = LGBaseView()
        headerView.glassIntensity = 0.2
        headerView.cornerRadius = 8
        
        let dayLabel = UILabel()
        dayLabel.text = day
        dayLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        dayLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        let countLabel = UILabel()
        countLabel.text = "\(taskCount) task\(taskCount == 1 ? "" : "s")"
        countLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        countLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        headerView.addSubview(dayLabel)
        headerView.addSubview(countLabel)
        
        dayLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        headerView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        return headerView
    }
}

class LGWeeklyViewModel: LGTaskListViewModel {
    
    override func createFetchRequest() -> NSFetchRequest<NTask> {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? Date()
        
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfWeek as NSDate, endOfWeek as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "isComplete", ascending: true),
            NSSortDescriptor(key: "taskPriority", ascending: true)
        ]
        
        return request
    }
}

// MARK: - Completed Tasks View Controller

class LGCompletedViewController: LGBaseListViewController {
    
    override func viewDidLoad() {
        setupViewModel()
        super.viewDidLoad()
        
        // Hide FAB for completed tasks
        fab.isHidden = true
    }
    
    override func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGCompletedViewModel(context: context)
    }
    
    override func configureTitle() {
        titleLabel.text = "Completed"
        subtitleLabel.text = "Finished tasks"
    }
    
    override func showFilterOptions() {
        let alert = UIAlertController(title: "Filter Completed Tasks", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Today", style: .default) { _ in
            (self.viewModel as? LGCompletedViewModel)?.setTimeRange(.today)
        })
        
        alert.addAction(UIAlertAction(title: "This Week", style: .default) { _ in
            (self.viewModel as? LGCompletedViewModel)?.setTimeRange(.week)
        })
        
        alert.addAction(UIAlertAction(title: "This Month", style: .default) { _ in
            (self.viewModel as? LGCompletedViewModel)?.setTimeRange(.month)
        })
        
        alert.addAction(UIAlertAction(title: "All Time", style: .default) { _ in
            (self.viewModel as? LGCompletedViewModel)?.setTimeRange(.all)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
            popover.sourceRect = filterButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    override func createTaskCard(for task: NTask) -> LGTaskCard {
        let taskCard = super.createTaskCard(for: task)
        
        // Customize for completed tasks
        taskCard.alpha = 0.8
        taskCard.isUserInteractionEnabled = true
        
        // Add completion date info
        if let completionDate = task.dateCompleted {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            // You could add a completion date label here
        }
        
        return taskCard
    }
}

class LGCompletedViewModel: LGTaskListViewModel {
    
    enum TimeRange {
        case today, week, month, all
    }
    
    private var currentTimeRange: TimeRange = .week
    
    override func createFetchRequest() -> NSFetchRequest<NTask> {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let now = Date()
        
        var startDate: Date
        switch currentTimeRange {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .all:
            startDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
        
        request.predicate = NSPredicate(format: "isComplete == YES AND dateCompleted >= %@", startDate as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "dateCompleted", ascending: false)
        ]
        
        return request
    }
    
    func setTimeRange(_ range: TimeRange) {
        currentTimeRange = range
        refreshTasks()
    }
}
