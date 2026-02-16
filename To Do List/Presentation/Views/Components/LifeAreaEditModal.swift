//
//  LifeAreaEditModal.swift
//  Tasker
//
//  Modal view for creating and editing Life Areas.
//  Features color grid selection and icon picker integration.
//

import SwiftUI

// MARK: - Life Area Edit Data

/// Data model for Life Area editing
public struct LifeAreaEditData: Equatable {
    public var name: String
    public var color: ProjectColor
    public var iconName: String

    public init(name: String = "", color: ProjectColor = .pastelBlue, iconName: String = "star.fill") {
        self.name = name
        self.color = color
        self.iconName = iconName
    }
}

// MARK: - Life Area Edit Modal

/// Modal view for creating and editing Life Areas
public struct LifeAreaEditModal: View {
    // MARK: - Properties

    /// Current edit state
    @Binding public var editData: LifeAreaEditData

    /// Whether the modal is presented
    @Binding public var isPresented: Bool

    /// Callback when user saves changes
    public let onSave: (LifeAreaEditData) -> Void

    /// Callback when user cancels
    public let onCancel: () -> Void

    /// Currently active tab in the modal
    @State private var activeTab: EditTab = .name

    /// Whether to show validation errors
    @State private var showValidationErrors: Bool = false

    /// Pastel colors for Life Areas
    private let pastelColors: [ProjectColor] = [
        .pastelRed,    // Rose
        .pastelPurple, // Lilac
        .pastelYellow, // Honey
        .pastelMint,   // Mint
        .pastelPink,   // Peach
        .pastelBlue,   // Sky
        .pastelGreen,  // Alternative green
        .pastelOrange  // Sand
    ]

    // MARK: - Initialization

    public init(
        editData: Binding<LifeAreaEditData>,
        isPresented: Binding<Bool>,
        onSave: @escaping (LifeAreaEditData) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self._editData = editData
        self._isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background dim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Modal content
            modalContent
        }
        .transition(.opacity)
    }

    // MARK: - Modal Content

    private var modalContent: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content area with tabs
            tabContent

            // Action buttons
            actionButtons
        }
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.xxl)
        .taskerElevation(.e3, cornerRadius: TaskerTheme.CornerRadius.xxl)
        .padding(TaskerTheme.Spacing.screenHorizontal)
        .frame(maxWidth: 480)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: TaskerTheme.Spacing.sm) {
            // Drag indicator
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill)
                .fill(TaskerTheme.Colors.divider)
                .frame(width: 36, height: 4)
                .padding(.top, TaskerTheme.Spacing.sm)

            // Title
            Text(editData.name.isEmpty ? "New Life Area" : "Edit Life Area")
                .font(TaskerTheme.Typography.title3)
                .foregroundColor(TaskerTheme.Colors.textPrimary)

            // Tab switcher
            tabSwitcher
        }
        .padding(TaskerTheme.Spacing.lg)
        .padding(.bottom, TaskerTheme.Spacing.md)
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            ForEach(EditTab.allCases) { tab in
                Button(action: {
                    withAnimation(TaskerTheme.Animation.standard) {
                        activeTab = tab
                    }
                }) {
                    HStack(spacing: TaskerTheme.Spacing.xs) {
                        Image(systemName: tab.iconName)
                            .font(.tasker(.caption1))
                        Text(tab.displayName)
                            .font(TaskerTheme.Typography.captionSemibold)
                    }
                    .foregroundColor(activeTab == tab ? TaskerTheme.Colors.textInverse : TaskerTheme.Colors.textSecondary)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .padding(.vertical, TaskerTheme.Spacing.sm)
                    .background(activeTab == tab ? TaskerTheme.Colors.coral : Color.clear)
                    .cornerRadius(TaskerTheme.CornerRadius.pill)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        Group {
            switch activeTab {
            case .name:
                nameTabContent
            case .color:
                colorTabContent
            case .icon:
                iconTabContent
            }
        }
        .frame(height: 280)
        .background(TaskerTheme.Colors.background)
    }

    // MARK: - Name Tab

    private var nameTabContent: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text("Life Area Name")
                    .font(TaskerTheme.Typography.sectionHeader)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)

                TextField("e.g., Health, Work, Fitness", text: $editData.name)
                    .font(TaskerTheme.Typography.body)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .padding(.vertical, TaskerTheme.Spacing.sm)
                    .background(TaskerTheme.Colors.cardBackground)
                    .cornerRadius(TaskerTheme.CornerRadius.md)
            }

            // Preview card
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text("Preview")
                    .font(TaskerTheme.Typography.sectionHeader)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)

                lifeAreaPreviewCard
            }

            Spacer()
        }
        .padding(TaskerTheme.Spacing.lg)
    }

    // MARK: - Color Tab

    private var colorTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                Text("Choose a Color")
                    .font(TaskerTheme.Typography.sectionHeader)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
                    .padding(.horizontal, TaskerTheme.Spacing.lg)
                    .padding(.top, TaskerTheme.Spacing.lg)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: TaskerTheme.Spacing.md),
                        GridItem(.flexible(), spacing: TaskerTheme.Spacing.md),
                        GridItem(.flexible(), spacing: TaskerTheme.Spacing.md),
                        GridItem(.flexible(), spacing: TaskerTheme.Spacing.md)
                    ],
                    spacing: TaskerTheme.Spacing.md
                ) {
                    ForEach(pastelColors, id: \.rawValue) { color in
                        colorButton(for: color)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
            }
            .padding(.bottom, TaskerTheme.Spacing.lg)
        }
    }

    /// Color selection button
    private func colorButton(for color: ProjectColor) -> some View {
        let isSelected = editData.color == color
        let colorValue = Color(hex: color.hexString)

        return Button(action: {
            withAnimation(TaskerTheme.Animation.standard) {
                editData.color = color
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg)
                    .fill(colorValue)
                    .frame(height: 60)

                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg)
                        .stroke(Color.white, lineWidth: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg)
                                .stroke(editData.color == color ? Color.black.opacity(0.2) : colorValue, lineWidth: 1)
                        )

                    Image(systemName: "checkmark.circle.fill")
                        .font(.tasker(.title2))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Icon Tab

    private var iconTabContent: some View {
        VStack(spacing: 0) {
            // Current selection preview
            HStack {
                Text("Current Icon")
                    .font(TaskerTheme.Typography.sectionHeader)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)

                Spacer()

                HStack(spacing: TaskerTheme.Spacing.xs) {
                    Image(systemName: editData.iconName)
                        .font(.tasker(.title3))
                        .foregroundColor(Color(hex: editData.color.hexString))
                    Text("Selected")
                        .font(TaskerTheme.Typography.caption)
                        .foregroundColor(TaskerTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.lg)
            .padding(.vertical, TaskerTheme.Spacing.md)

            Divider()

            // Icon picker (embedded, simplified)
            iconPickerGrid
        }
        .background(TaskerTheme.Colors.cardBackground)
    }

    /// Simplified icon picker grid for modal
    private var iconPickerGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                ForEach(IconCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                        // Category header
                        HStack(spacing: TaskerTheme.Spacing.xs) {
                            Image(systemName: category.categoryIcon)
                                .font(.tasker(.caption1))
                                .foregroundColor(category.categoryColor)

                            Text(category.rawValue.uppercased())
                                .font(TaskerTheme.Typography.captionSemibold)
                                .foregroundColor(TaskerTheme.Colors.textSecondary)

                            Spacer()
                        }
                        .padding(.horizontal, TaskerTheme.Spacing.lg)

                        // Icon grid for this category
                        let categoryIcons = IconPickerView.defaultIcons.filter { $0.category == category }
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 50, maximum: 70), spacing: TaskerTheme.Spacing.md)
                            ],
                            spacing: TaskerTheme.Spacing.md
                        ) {
                            ForEach(categoryIcons) { icon in
                                iconGridButton(icon)
                            }
                        }
                        .padding(.horizontal, TaskerTheme.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, TaskerTheme.Spacing.lg)
        }
    }

    /// Icon grid button
    private func iconGridButton(_ icon: IconOption) -> some View {
        let isSelected = editData.iconName == icon.iconName

        return Button(action: {
            withAnimation(TaskerTheme.Animation.standard) {
                editData.iconName = icon.iconName
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg)
                    .fill(isSelected ? icon.category.categoryColor.opacity(0.15) : TaskerTheme.Colors.background)
                    .frame(width: 50, height: 50)

                Image(systemName: icon.iconName)
                    .font(.tasker(.title2))
                    .foregroundColor(isSelected ? icon.category.categoryColor : TaskerTheme.Colors.textPrimary)

                if isSelected {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.tasker(.caption1))
                                .foregroundColor(icon.category.categoryColor)
                        }
                    }
                    .padding(2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Preview Card

    private var lifeAreaPreviewCard: some View {
        HStack(spacing: TaskerTheme.Spacing.md) {
            // Icon with color background
            ZStack {
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
                    .fill(Color(hex: editData.color.hexString))
                    .frame(width: 44, height: 44)

                Image(systemName: editData.iconName)
                    .font(.tasker(.title3))
                    .foregroundColor(.white)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(editData.name.isEmpty ? "Life Area Name" : editData.name)
                    .font(TaskerTheme.Typography.bodySemibold)
                    .foregroundColor(TaskerTheme.Colors.textPrimary)

                Text("Preview")
                    .font(TaskerTheme.Typography.caption)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(TaskerTheme.Spacing.md)
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.lg)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: TaskerTheme.Spacing.md) {
            // Cancel button
            Button(action: dismiss) {
                Text("Cancel")
                    .font(TaskerTheme.Typography.bodySemibold)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TaskerTheme.Spacing.md)
                    .background(TaskerTheme.Colors.background)
                    .cornerRadius(TaskerTheme.CornerRadius.button)
            }

            // Save button
            Button(action: save) {
                Text("Save")
                    .font(TaskerTheme.Typography.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TaskerTheme.Spacing.md)
                    .background(editData.name.isEmpty ? TaskerTheme.Colors.textTertiary : TaskerTheme.Colors.coral)
                    .cornerRadius(TaskerTheme.CornerRadius.button)
            }
            .disabled(editData.name.isEmpty)
        }
        .padding(TaskerTheme.Spacing.lg)
    }

    // MARK: - Actions

    private func save() {
        onSave(editData)
        dismiss()
    }

    private func dismiss() {
        onCancel()
        withAnimation {
            isPresented = false
        }
    }
}

// MARK: - Edit Tab

enum EditTab: String, CaseIterable, Identifiable {
    case name
    case color
    case icon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .color: return "Color"
        case .icon: return "Icon"
        }
    }

    var iconName: String {
        switch self {
        case .name: return "text.alignleft"
        case .color: return "paintpalette.fill"
        case .icon: return "star.fill"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LifeAreaEditModal_Previews: PreviewProvider {
    static var previews: some View {
        LifeAreaEditModal(
            editData: .constant(LifeAreaEditData()),
            isPresented: .constant(true),
            onSave: { _ in logDebug("Save tapped") },
            onCancel: { logDebug("Cancel tapped") }
        )
        .previewDisplayName("Life Area Edit Modal")
    }
}
#endif
