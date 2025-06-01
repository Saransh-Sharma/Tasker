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
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textAlignment = .center
        
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
        if isSelected {
            contentView.backgroundColor = UIColor(red: 0.19, green: 0.57, blue: 1, alpha: 1)
            titleLabel.textColor = .white
            contentView.layer.borderColor = UIColor(red: 0.19, green: 0.57, blue: 1, alpha: 1).cgColor
        } else {
            contentView.backgroundColor = .systemBackground
            titleLabel.textColor = .label
            contentView.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}
