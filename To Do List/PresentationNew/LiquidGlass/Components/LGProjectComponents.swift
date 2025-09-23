// LGProjectComponents.swift
// Specialized project management components - Phase 5 Implementation
// Project cards, stats cards, and project-specific UI elements

import UIKit
import SnapKit
import RxSwift
import RxCocoa

// MARK: - Project Card

class LGProjectCard: LGBaseView {
    
    enum Style {
        case list, grid, kanban
    }
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let progressView = LGProgressBar()
    private let progressLabel = UILabel()
    private let taskCountLabel = UILabel()
    private let dateLabel = UILabel()
    private let colorIndicator = UIView()
    private let statusBadge = LGBadge()
    private let actionButton = LGButton(style: .ghost, size: .small)
    
    // MARK: - Properties
    var project: Projects? {
        didSet {
            updateContent()
        }
    }
    
    var onProjectTap: (() -> Void)?
    var onEditTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    
    private let style: Style
    
    // MARK: - Initialization
    
    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        self.style = .list
        super.init(coder: coder)
        setupCard()
    }
    
    // MARK: - Setup
    
    private func setupCard() {
        glassIntensity = 0.7
        cornerRadius = 12
        enableGlassBorder = true
        
        setupSubviews()
        setupConstraints()
        setupInteractions()
        applyTheme()
    }
    
    private func setupSubviews() {
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        titleLabel.numberOfLines = style == .grid ? 2 : 1
        
        descriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        descriptionLabel.textColor = LGThemeManager.shared.secondaryTextColor
        descriptionLabel.numberOfLines = style == .list ? 1 : 2
        
        progressView.style = .linear
        progressView.height = 4
        progressView.enableShimmerEffect = true
        
        progressLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        progressLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        taskCountLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        taskCountLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        dateLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        dateLabel.textColor = LGThemeManager.shared.tertiaryTextColor
        
        colorIndicator.layer.cornerRadius = 3
        
        statusBadge.size = .small
        
        actionButton.icon = UIImage(systemName: "ellipsis")
        
        addSubview(colorIndicator)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(progressView)
        addSubview(progressLabel)
        addSubview(taskCountLabel)
        addSubview(dateLabel)
        addSubview(statusBadge)
        addSubview(actionButton)
    }
    
    private func setupConstraints() {
        switch style {
        case .list:
            setupListConstraints()
        case .grid:
            setupGridConstraints()
        case .kanban:
            setupKanbanConstraints()
        }
    }
    
    private func setupListConstraints() {
        colorIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(6)
            make.height.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(colorIndicator.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(16)
            make.trailing.equalTo(actionButton.snp.leading).offset(-8)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.equalTo(titleLabel)
        }
        
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-32)
            make.width.equalTo(100)
        }
        
        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressView.snp.trailing).offset(8)
            make.centerY.equalTo(progressView)
        }
        
        taskCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        statusBadge.snp.makeConstraints { make in
            make.trailing.equalTo(actionButton.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(16)
        }
        
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(32)
        }
    }
    
    private func setupGridConstraints() {
        colorIndicator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(4)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(colorIndicator.snp.bottom).offset(16)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
        
        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        progressLabel.snp.makeConstraints { make in
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(progressView.snp.bottom).offset(8)
        }
        
        taskCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.centerY.equalTo(progressLabel)
        }
        
        statusBadge.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(16)
        }
        
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-8)
            make.size.equalTo(28)
        }
    }
    
    private func setupKanbanConstraints() {
        colorIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(4)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(colorIndicator.snp.trailing).offset(12)
            make.trailing.equalTo(actionButton.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(12)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
        
        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-28)
        }
        
        progressLabel.snp.makeConstraints { make in
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-8)
        }
        
        taskCountLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.centerY.equalTo(progressLabel)
        }
        
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(8)
            make.size.equalTo(24)
        }
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
        
        actionButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.showActionMenu()
            })
            .disposed(by: disposeBag)
    }
    
    private func updateContent() {
        guard let project = project else { return }
        
        titleLabel.text = project.name
        descriptionLabel.text = project.projectDescription
        
        // Calculate progress
        let stats = calculateProjectStats(project)
        progressView.setProgress(stats.progress, animated: true)
        progressLabel.text = "\(stats.progressPercentage)%"
        
        // Task count
        taskCountLabel.text = "\(stats.totalTasks) tasks"
        
        // Date
        if let dateCreated = project.dateCreated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            dateLabel.text = formatter.string(from: dateCreated)
        }
        
        // Color
        if let colorData = project.color,
           let color = UIColor.from(data: colorData) {
            colorIndicator.backgroundColor = color
        } else {
            colorIndicator.backgroundColor = LGThemeManager.shared.primaryGlassColor
        }
        
        // Status
        if project.isCompleted {
            statusBadge.configure(text: "Completed", style: .success)
        } else if project.isArchived {
            statusBadge.configure(text: "Archived", style: .neutral)
        } else {
            statusBadge.configure(text: "Active", style: .primary)
        }
        
        // Apply completion styling
        if project.isCompleted {
            alpha = 0.8
            titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        } else {
            alpha = 1.0
            titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        }
    }
    
    @objc private func handleTap() {
        morphGlass(to: .pressed) { [weak self] in
            self?.morphGlass(to: .idle)
            self?.onProjectTap?()
        }
    }
    
    private func showActionMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.onEditTap?()
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.onDeleteTap?()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let viewController = findViewController() {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = actionButton
                popover.sourceRect = actionButton.bounds
            }
            viewController.present(alert, animated: true)
        }
    }
    
    private func calculateProjectStats(_ project: Projects) -> ProjectStats {
        guard let tasks = project.tasks?.allObjects as? [NTask] else {
            return ProjectStats(totalTasks: 0, completedTasks: 0, progress: 0.0)
        }
        
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isComplete }.count
        let progress = totalTasks > 0 ? Float(completedTasks) / Float(totalTasks) : 0.0
        
        return ProjectStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            progress: progress
        )
    }
    
    private func applyTheme() {
        backgroundColor = LGThemeManager.shared.cardBackgroundColor
    }
    
    private let disposeBag = DisposeBag()
}

// MARK: - Project Stats Card

class LGProjectStatsCard: LGBaseView {
    
    // MARK: - UI Components
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let trendIndicator = UIImageView()
    
    // MARK: - Properties
    var value: String = "0" {
        didSet {
            valueLabel.text = value
            animateValueChange()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    // MARK: - Setup
    
    private func setupCard() {
        glassIntensity = 0.6
        cornerRadius = 12
        enableGlassBorder = true
        
        setupSubviews()
        setupConstraints()
        applyTheme()
    }
    
    private func setupSubviews() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        titleLabel.textAlignment = .center
        
        valueLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        valueLabel.textColor = LGThemeManager.shared.primaryTextColor
        valueLabel.textAlignment = .center
        
        trendIndicator.contentMode = .scaleAspectFit
        trendIndicator.tintColor = .systemGreen
        trendIndicator.isHidden = true
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(trendIndicator)
    }
    
    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.size.equalTo(24)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(4)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        trendIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(8)
            make.size.equalTo(16)
        }
    }
    
    // MARK: - Public Methods
    
    func configure(title: String, value: String, icon: UIImage?, color: UIColor) {
        titleLabel.text = title
        self.value = value
        iconImageView.image = icon
        iconImageView.tintColor = color
    }
    
    func showTrend(_ isPositive: Bool) {
        trendIndicator.image = UIImage(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
        trendIndicator.tintColor = isPositive ? .systemGreen : .systemRed
        trendIndicator.isHidden = false
        
        trendIndicator.morphGlass(to: .shimmerPulse, config: .subtle)
    }
    
    private func animateValueChange() {
        valueLabel.morphGlass(to: .liquidWave, config: .default) {
            self.valueLabel.morphGlass(to: .idle, config: .subtle)
        }
    }
    
    private func applyTheme() {
        backgroundColor = LGThemeManager.shared.cardBackgroundColor
    }
}

// MARK: - Project Filter Pill

class LGProjectFilterPill: LGBaseView {
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    // MARK: - Properties
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPill()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPill()
    }
    
    // MARK: - Setup
    
    private func setupPill() {
        glassIntensity = 0.5
        cornerRadius = 16
        
        setupSubviews()
        setupConstraints()
        setupInteractions()
        updateAppearance()
    }
    
    private func setupSubviews() {
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        titleLabel.textAlignment = .center
        
        countLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .bold)
        countLabel.textAlignment = .center
        
        addSubview(titleLabel)
        addSubview(countLabel)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        
        snp.makeConstraints { make in
            make.height.equalTo(32)
        }
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        morphGlass(to: .pressed) { [weak self] in
            self?.morphGlass(to: .idle)
            self?.onTap?()
        }
    }
    
    // MARK: - Public Methods
    
    func configure(title: String, count: Int) {
        titleLabel.text = title
        countLabel.text = "\(count)"
    }
    
    private func updateAppearance() {
        if isSelected {
            backgroundColor = LGThemeManager.shared.primaryGlassColor.withAlphaComponent(0.3)
            titleLabel.textColor = LGThemeManager.shared.primaryTextColor
            countLabel.textColor = LGThemeManager.shared.primaryTextColor
            glassIntensity = 0.8
        } else {
            backgroundColor = .clear
            titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
            countLabel.textColor = LGThemeManager.shared.tertiaryTextColor
            glassIntensity = 0.3
        }
    }
}

// MARK: - Extensions

extension UIColor {
    static func from(data: Data) -> UIColor? {
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor
    }
    
    func toData() -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
}

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

// MARK: - Reactive Extensions

extension Reactive where Base: LGProjectStatsCard {
    var value: Binder<String> {
        return Binder(base) { card, value in
            card.value = value
        }
    }
}
