//
//  ThemeSelectionCell.swift
//  To Do List
//
//  Created to embed horizontal theme picker inside Settings.
//

import UIKit
import Combine

/// Table view cell hosting a horizontally scrollable picker of theme cards
class ThemeSelectionCell: UITableViewCell {
    static let reuseID = "ThemeSelectionCell"
    
    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()
    private var currentIndex: Int { TaskerThemeManager.shared.selectedThemeIndex }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureCollectionView()
        selectionStyle = .none
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCollectionView()
        selectionStyle = .none
    }
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ThemeCardCell.self, forCellWithReuseIdentifier: ThemeCardCell.reuseID)
        
        contentView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 96)
        ])
        
        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - CollectionView DataSource & Delegate
extension ThemeSelectionCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return TaskerThemeManager.shared.availableThemeSwatches.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThemeCardCell.reuseID, for: indexPath) as! ThemeCardCell
        let swatch = TaskerThemeManager.shared.availableThemeSwatches[indexPath.item]
        cell.configure(primary: swatch.primary, secondary: swatch.secondary, selected: indexPath.item == currentIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        TaskerThemeManager.shared.selectTheme(index: indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 60, height: 80)
    }
}

// MARK: - Theme Card Cell
private class ThemeCardCell: UICollectionViewCell {
    static let reuseID = "ThemeCardCell"
    
    private let primaryView = UIView()
    private let secondaryView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        layer.borderWidth = 2
        layer.masksToBounds = true
        contentView.clipsToBounds = true
        
        primaryView.translatesAutoresizingMaskIntoConstraints = false
        secondaryView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(primaryView)
        contentView.addSubview(secondaryView)
        
        NSLayoutConstraint.activate([
            primaryView.topAnchor.constraint(equalTo: contentView.topAnchor),
            primaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            primaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            primaryView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),
            
            secondaryView.topAnchor.constraint(equalTo: primaryView.bottomAnchor),
            secondaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            secondaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            secondaryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(primary: UIColor, secondary: UIColor, selected: Bool) {
        primaryView.backgroundColor = primary
        secondaryView.backgroundColor = secondary
        layer.borderColor = selected ? primary.cgColor : UIColor.clear.cgColor
    }
}
