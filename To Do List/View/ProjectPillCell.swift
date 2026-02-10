//
//  ProjectPillCell.swift
//  To Do List
//
//  Created by Saransh Sharma on 31/05/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit

class ProjectPillCell: UICollectionViewCell {
    
    private let titleLabel = UILabel()
    var selectedStyle: TaskerChipSelectionStyle = .tinted
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.backgroundColor = UIColor.tasker.chipUnselectedBackground
        contentView.layer.cornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.chip
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = UIColor.clear.cgColor
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.tasker.font(for: .callout)
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor.tasker.textSecondary
        
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        // Set a minimum width for the pill
        contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
    }
    
    func configure(with projectName: String) {
        titleLabel.text = projectName
        updateAppearance()
    }
    
    private func updateAppearance() {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        if isSelected {
            switch selectedStyle {
            case .tinted:
                contentView.backgroundColor = colors.accentMuted
                titleLabel.textColor = colors.accentPrimary
                contentView.layer.borderColor = colors.accentRing.cgColor
                contentView.layer.borderWidth = 1
            case .filled:
                contentView.backgroundColor = colors.chipSelectedBackground
                titleLabel.textColor = colors.accentOnPrimary
                contentView.layer.borderColor = UIColor.clear.cgColor
                contentView.layer.borderWidth = 0
            }
        } else {
            contentView.backgroundColor = colors.chipUnselectedBackground
            titleLabel.textColor = colors.textSecondary
            contentView.layer.borderColor = UIColor.clear.cgColor
            contentView.layer.borderWidth = 0
        }
    }
}
