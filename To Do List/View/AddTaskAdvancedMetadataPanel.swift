import UIKit

final class AddTaskAdvancedMetadataPanel: UIView {
    var onLifeAreaTapped: (() -> Void)?
    var onSectionTapped: (() -> Void)?
    var onTagsTapped: (() -> Void)?
    var onParentTapped: (() -> Void)?
    var onDependenciesTapped: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Task Metadata"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        return label
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    private lazy var lifeAreaButton = makeButton(selector: #selector(lifeAreaTapped))
    private lazy var sectionButton = makeButton(selector: #selector(sectionTapped))
    private lazy var tagsButton = makeButton(selector: #selector(tagsTapped))
    private lazy var parentButton = makeButton(selector: #selector(parentTapped))
    private lazy var dependenciesButton = makeButton(selector: #selector(dependenciesTapped))

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        backgroundColor = .secondarySystemBackground

        addSubview(titleLabel)
        addSubview(stack)
        [lifeAreaButton, sectionButton, tagsButton, parentButton, dependenciesButton].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        lifeAreas: [LifeArea],
        selectedLifeAreaID: UUID?,
        sections: [TaskerProjectSection],
        selectedSectionID: UUID?,
        tags: [TagDefinition],
        selectedTagIDs: Set<UUID>,
        parentTasks: [Task],
        selectedParentTaskID: UUID?,
        dependencyTasks: [Task],
        selectedDependencyTaskIDs: Set<UUID>
    ) {
        let selectedLifeArea = lifeAreas.first(where: { $0.id == selectedLifeAreaID })?.name ?? "None"
        let selectedSection = sections.first(where: { $0.id == selectedSectionID })?.name ?? "None"
        let selectedTagNames = tags
            .filter { selectedTagIDs.contains($0.id) }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let selectedParent = parentTasks.first(where: { $0.id == selectedParentTaskID })?.name ?? "None"
        let selectedDependencyCount = selectedDependencyTaskIDs.count

        updateButton(lifeAreaButton, title: "Life Area", value: selectedLifeArea)
        updateButton(sectionButton, title: "Section", value: selectedSection)
        updateButton(tagsButton, title: "Tags", value: selectedTagNames.isEmpty ? "None" : selectedTagNames.joined(separator: ", "))
        updateButton(parentButton, title: "Parent Task", value: selectedParent)
        updateButton(
            dependenciesButton,
            title: "Dependencies",
            value: selectedDependencyCount == 0 ? "None" : "\(selectedDependencyCount) selected"
        )
    }

    private func makeButton(selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        button.titleLabel?.numberOfLines = 2
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func updateButton(_ button: UIButton, title: String, value: String) {
        button.setTitle("\(title): \(value)", for: .normal)
    }

    @objc private func lifeAreaTapped() { onLifeAreaTapped?() }
    @objc private func sectionTapped() { onSectionTapped?() }
    @objc private func tagsTapped() { onTagsTapped?() }
    @objc private func parentTapped() { onParentTapped?() }
    @objc private func dependenciesTapped() { onDependenciesTapped?() }
}
