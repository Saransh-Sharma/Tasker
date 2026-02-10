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

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        title = "Choose Theme"

        configureCollectionView()
    }

    // MARK: - UI Setup
    private func configureCollectionView() {
        let spacing = TaskerThemeManager.shared.currentTheme.tokens.spacing
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing.s16
        layout.sectionInset = UIEdgeInsets(top: 0, left: spacing.s16, bottom: 0, right: spacing.s16)
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
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: spacing.s24),
            collectionView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

}

// MARK: - UICollectionViewDataSource
extension ThemeSelectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return TaskerThemeManager.shared.availableThemeSwatches.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as? ThemeCardCell else {
            return UICollectionViewCell()
        }
        let swatch = TaskerThemeManager.shared.availableThemeSwatches[indexPath.item]
        cell.configure(
            primary: swatch.primary,
            secondary: swatch.secondary,
            isSelected: indexPath.item == TaskerThemeManager.shared.selectedThemeIndex
        )
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ThemeSelectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Persist selection
        TaskerThemeManager.shared.selectTheme(index: indexPath.item)
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

        layer.cornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.r1
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
        layer.borderColor = isSelected ? TaskerThemeManager.shared.currentTheme.tokens.color.accentRing.cgColor : nil
    }
}

final class ThemeDebugSwatchesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let reuseIdentifier = "ThemeDebugSwatchCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Theme QA Swatches"
        view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        setupTableView()
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func summary(for index: Int) -> String {
        let theme = TaskerTheme(index: index)
        let colors = theme.tokens.color
        let traits = traitCollection
        let accent = colors.accentPrimary.resolvedColor(with: traits)
        let ring = colors.accentRing.resolvedColor(with: traits)
        let onAccent = colors.accentOnPrimary.resolvedColor(with: traits)
        let textInverse = colors.textInverse.resolvedColor(with: traits)
        let ratio = contrastRatio(between: accent, and: textInverse)
        return "accent500 \(accent.taskerHexString) • ring \(ring.taskerHexString) • onAccent \(onAccent.taskerHexString) • contrast \(String(format: "%.2f", ratio)):1"
    }

    private func contrastRatio(between lhs: UIColor, and rhs: UIColor) -> Double {
        let lhsL = lhs.taskerRelativeLuminance
        let rhsL = rhs.taskerRelativeLuminance
        let lighter = max(lhsL, rhsL)
        let darker = min(lhsL, rhsL)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

extension ThemeDebugSwatchesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        TaskerTheme.accentThemes.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Tap a swatch to preview/apply"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let index = indexPath.row
        let theme = TaskerTheme(index: index)
        let colors = theme.tokens.color

        cell.textLabel?.text = "\(theme.accentTheme.name)"
        cell.textLabel?.font = UIFont.tasker.bodyEmphasis
        cell.detailTextLabel?.text = summary(for: index)
        cell.detailTextLabel?.font = UIFont.tasker.caption2
        cell.detailTextLabel?.numberOfLines = 0
        cell.backgroundColor = colors.surfacePrimary
        cell.tintColor = TaskerThemeManager.shared.currentTheme.tokens.color.accentPrimary
        cell.accessoryType = TaskerThemeManager.shared.selectedThemeIndex == index ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        TaskerThemeManager.shared.selectTheme(index: indexPath.row)
        tableView.reloadData()
    }
}

private extension UIColor {
    var taskerHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "#000000" }
        let redInt = Int(round(red * 255))
        let greenInt = Int(round(green * 255))
        let blueInt = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }

    var taskerRelativeLuminance: Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }

        func convert(_ value: CGFloat) -> Double {
            let srgb = Double(value)
            if srgb <= 0.04045 {
                return srgb / 12.92
            }
            return pow((srgb + 0.055) / 1.055, 2.4)
        }

        let redLin = convert(red)
        let greenLin = convert(green)
        let blueLin = convert(blue)
        return (0.2126 * redLin) + (0.7152 * greenLin) + (0.0722 * blueLin)
    }
}
