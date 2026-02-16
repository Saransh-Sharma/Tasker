import UIKit
import Combine

// MARK: - Unified Theme Picker Cell

/// "Gem gallery" theme picker — horizontal scroll of gradient preview cards
/// Replaces the flat-color ThemeSelectionCell with actual gradient previews
final class UnifiedThemePickerCell: UITableViewCell {
    static let reuseID = "UnifiedThemePickerCell"

    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()

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
        layout.minimumLineSpacing = TaskerUIKitTokens.spacing.s12
        layout.sectionInset = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        layout.itemSize = CGSize(width: 72, height: 112)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GemThemeCardCell.self, forCellWithReuseIdentifier: GemThemeCardCell.reuseID)

        contentView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 120)
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

// MARK: - Collection View DataSource & Delegate

extension UnifiedThemePickerCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        TaskerTheme.accentThemes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GemThemeCardCell.reuseID, for: indexPath) as! GemThemeCardCell
        let theme = TaskerTheme(index: indexPath.item)
        let isSelected = indexPath.item == TaskerThemeManager.shared.selectedThemeIndex
        cell.configure(theme: theme, isSelected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        TaskerFeedback.selection()
        TaskerThemeManager.shared.selectTheme(index: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 72, height: 112)
    }
}

// MARK: - Gem Theme Card Cell

private final class GemThemeCardCell: UICollectionViewCell {
    static let reuseID = "GemThemeCardCell"

    private let gradientContainer = UIView()
    private let nameLabel = UILabel()
    private let checkmarkView = UIImageView()
    private var gradientLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(theme: TaskerTheme, isSelected: Bool) {
        let colors = theme.tokens.color

        // Apply gradient
        gradientLayer?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.colors = [
            colors.accentPrimary.cgColor,
            colors.accentSecondary.cgColor
        ]
        gl.startPoint = CGPoint(x: 0, y: 0)
        gl.endPoint = CGPoint(x: 1, y: 1)
        gl.frame = gradientContainer.bounds
        gl.cornerRadius = TaskerUIKitTokens.corner.r2
        gradientContainer.layer.insertSublayer(gl, at: 0)
        gradientLayer = gl

        // Theme name
        nameLabel.text = theme.accentTheme.name

        // Selection state
        checkmarkView.isHidden = !isSelected

        if isSelected {
            gradientContainer.layer.borderWidth = 2.5
            gradientContainer.layer.borderColor = colors.accentPrimary.cgColor
            // Glow
            gradientContainer.layer.shadowColor = colors.accentPrimary.cgColor
            gradientContainer.layer.shadowOffset = .zero
            gradientContainer.layer.shadowRadius = 6
            gradientContainer.layer.shadowOpacity = 0.4
            // Slight scale
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
                self.gradientContainer.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
            }
        } else {
            gradientContainer.layer.borderWidth = 0.5
            gradientContainer.layer.borderColor = TaskerUIKitTokens.color.strokeHairline.cgColor
            gradientContainer.layer.shadowOpacity = 0
            gradientContainer.transform = .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = gradientContainer.bounds
    }

    private func setup() {
        // Gradient card container
        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.layer.cornerRadius = TaskerUIKitTokens.corner.r2
        gradientContainer.layer.cornerCurve = .continuous
        gradientContainer.clipsToBounds = false
        contentView.addSubview(gradientContainer)

        // Checkmark overlay (centered)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        checkmarkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        checkmarkView.tintColor = .white
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.isHidden = true
        // Add slight shadow for legibility on any gradient
        checkmarkView.layer.shadowColor = UIColor.black.cgColor
        checkmarkView.layer.shadowOffset = .zero
        checkmarkView.layer.shadowRadius = 2
        checkmarkView.layer.shadowOpacity = 0.3
        gradientContainer.addSubview(checkmarkView)

        // Theme name label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = TaskerUIKitTokens.typography.caption2
        nameLabel.textColor = TaskerUIKitTokens.color.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.75
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            gradientContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientContainer.heightAnchor.constraint(equalToConstant: 80),

            checkmarkView.centerXAnchor.constraint(equalTo: gradientContainer.centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: gradientContainer.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: gradientContainer.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
}
