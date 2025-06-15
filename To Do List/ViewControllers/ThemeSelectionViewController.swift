//
//  ThemeSelectionViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 15/06/25.
//

import UIKit

// A simple collection-view-based UI that lets users choose among predefined themes.
// Each cell renders a visual card consisting of two rectangles: the top 80 % shows the
// theme's primary colour and the bottom 20 % shows the secondary colour.
class ThemeSelectionViewController: UIViewController {

    // MARK: - Properties
    private var collectionView: UICollectionView!
    private let cellReuseIdentifier = "ThemeCardCell"

    // Convenience access to themes
    private let themes = ToDoColors.themes

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Choose Theme"

        configureCollectionView()
    }

    // MARK: - UI Setup
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        layout.itemSize = CGSize(width: 80, height: 100)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ThemeCardCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            collectionView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

}

// MARK: - UICollectionViewDataSource
extension ThemeSelectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return themes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as? ThemeCardCell else {
            return UICollectionViewCell()
        }
        let theme = themes[indexPath.item]
        cell.configure(primary: theme.primary, secondary: theme.secondary, isSelected: indexPath.item == ToDoColors.currentIndex)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ThemeSelectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Persist selection
        ToDoColors.setTheme(index: indexPath.item)
        // Refresh visuals
        collectionView.reloadData()
        // Pop back after slight delay to show selection feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - Collection View Cell
private class ThemeCardCell: UICollectionViewCell {

    private let primaryView = UIView()
    private let secondaryView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.cornerRadius = 8
        layer.masksToBounds = true

        primaryView.translatesAutoresizingMaskIntoConstraints = false
        secondaryView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(primaryView)
        contentView.addSubview(secondaryView)

        NSLayoutConstraint.activate([
            // Primary occupies 80 % height
            primaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            primaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            primaryView.topAnchor.constraint(equalTo: contentView.topAnchor),
            primaryView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

            // Secondary occupies remaining 20 %
            secondaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            secondaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            secondaryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            secondaryView.topAnchor.constraint(equalTo: primaryView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(primary: UIColor, secondary: UIColor, isSelected: Bool) {
        primaryView.backgroundColor = primary
        secondaryView.backgroundColor = secondary

        layer.borderWidth = isSelected ? 3 : 0
        layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : nil
    }
}
