// LGSidebarViewController.swift
// iPad sidebar navigation - Phase 6 Implementation
// Optimized sidebar for iPad with glass morphism effects

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LGSidebarViewController: UIViewController {
    
    // MARK: - Properties
    
    var onItemSelected: ((SidebarItem) -> Void)?
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = LGBaseView()
    private let profileImageView = UIImageView()
    private let userNameLabel = UILabel()
    
    private let menuItems: [(title: String, icon: String, item: SidebarItem)] = [
        ("Home", "house.fill", .home),
        ("Today", "calendar.badge.clock", .today),
        ("Upcoming", "calendar", .upcoming),
        ("Projects", "folder.fill", .projects),
        ("Settings", "gear", .settings)
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupBindings()
        applyTheme()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        
        // Configure header
        headerView.glassIntensity = 0.8
        headerView.cornerRadius = 0
        
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = 30
        profileImageView.clipsToBounds = true
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        
        userNameLabel.text = "John Doe"
        userNameLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        userNameLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        headerView.addSubview(profileImageView)
        headerView.addSubview(userNameLabel)
        
        // Configure table view
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(SidebarCell.self, forCellReuseIdentifier: "SidebarCell")
        tableView.delegate = self
        tableView.dataSource = self
        
        view.addSubview(headerView)
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(120)
        }
        
        profileImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(60)
        }
        
        userNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(profileImageView)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func setupBindings() {
        // Add any reactive bindings here
    }
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        userNameLabel.textColor = LGThemeManager.shared.primaryTextColor
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension LGSidebarViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SidebarCell", for: indexPath) as! SidebarCell
        let item = menuItems[indexPath.row]
        cell.configure(title: item.title, icon: item.icon)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LGSidebarViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = menuItems[indexPath.row].item
        onItemSelected?(item)
        
        // Visual feedback
        if let cell = tableView.cellForRow(at: indexPath) as? SidebarCell {
            cell.animateSelection()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

// MARK: - Sidebar Cell

class SidebarCell: UITableViewCell {
    
    private let containerView = LGBaseView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.glassIntensity = 0.3
        containerView.cornerRadius = 12
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16))
        }
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }
    
    func configure(title: String, icon: String) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
    }
    
    func animateSelection() {
        LGAnimationRefinement.shared.pulseAnimation(for: containerView)
    }
}
