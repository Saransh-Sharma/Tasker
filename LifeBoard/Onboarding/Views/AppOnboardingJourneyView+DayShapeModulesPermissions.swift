import SwiftUI

extension AppOnboardingJourneyView {

    // MARK: - Day shape

    var dayShapeStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.DayShape.title,
                subtitle: OnboardingCopy.DayShape.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.dayShape)

            VStack(alignment: .leading, spacing: spacing.s16) {
                hoursRow(
                    title: OnboardingCopy.DayShape.weekdays,
                    start: viewModel.dayShape.weekdayStartMinute,
                    end: viewModel.dayShape.weekdayEndMinute,
                    identifier: "weekday"
                ) { start, end in
                    viewModel.setDayShapeWeekdayHours(start: start, end: end)
                }

                Divider().overlay(Color.lifeboard(.divider))

                Toggle(OnboardingCopy.DayShape.worksWeekends, isOn: Binding(
                    get: { viewModel.dayShape.worksWeekends },
                    set: { newValue in
                        registerSelection()
                        viewModel.setWorksWeekends(newValue)
                    }
                ))
                .tint(Color.lifeboard(.accentPrimary))
                .accessibilityIdentifier(AppOnboardingAccessibilityID.worksWeekends)

                if viewModel.dayShape.worksWeekends {
                    hoursRow(
                        title: OnboardingCopy.DayShape.weekends,
                        start: viewModel.dayShape.weekendStartMinute,
                        end: viewModel.dayShape.weekendEndMinute,
                        identifier: "weekend"
                    ) { start, end in
                        viewModel.setDayShapeWeekendHours(start: start, end: end)
                    }
                    .transition(.opacity)
                }
            }
            .padding(spacing.s16)
            .lifeBoardClaySurface(.raised)
            .animation(reduceMotion ? nil : LifeBoardAnimation.stateChange, value: viewModel.dayShape.worksWeekends)

            weekStartRow
        }
    }

    private func hoursRow(
        title: String,
        start: Int,
        end: Int,
        identifier: String,
        onChange: @escaping (Int, Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack {
                Text(title)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Spacer()
                Text("\(OnboardingDayShapeDraft.label(forMinute: start)) – \(OnboardingDayShapeDraft.label(forMinute: end))")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: spacing.s16) {
                minuteStepper(value: start, identifier: "\(identifier).start", label: "\(title) start") { newValue in
                    onChange(newValue, end)
                }
                Spacer(minLength: 0)
                minuteStepper(value: end, identifier: "\(identifier).end", label: "\(title) end") { newValue in
                    onChange(start, newValue)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Half-hour granularity keeps the control honest without a picker wheel.
    private func minuteStepper(
        value: Int,
        identifier: String,
        label: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        Stepper(
            value: Binding(
                get: { value },
                set: { newValue in
                    registerSelection()
                    onChange(newValue)
                }
            ),
            in: 0...(24 * 60),
            step: 30
        ) {
            // Visually empty on purpose: the range is stated once, above. The
            // label is still carried for VoiceOver via `accessibilityValue`.
            EmptyView()
        }
        .labelsHidden()
        .accessibilityIdentifier("onboarding.dayShape.\(identifier)")
        .accessibilityLabel(label)
        .accessibilityValue(OnboardingDayShapeDraft.label(forMinute: value))
    }

    private var weekStartRow: some View {
        HStack {
            Text(OnboardingCopy.DayShape.weekStarts)
                .lifeboardFont(.bodyEmphasis)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Spacer()
            Picker(OnboardingCopy.DayShape.weekStarts, selection: Binding(
                get: { viewModel.dayShape.weekStartsOn },
                set: { newValue in
                    registerSelection()
                    viewModel.setWeekStartsOn(newValue)
                }
            )) {
                ForEach(Weekday.allCases, id: \.self) { weekday in
                    Text(weekday.displayTitle).tag(weekday)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.lifeboard(.accentPrimary))
            .accessibilityIdentifier(AppOnboardingAccessibilityID.weekStartsOn)
        }
        .padding(spacing.s16)
        .lifeBoardClaySurface(.resting)
    }

    // MARK: - Modules

    /// The step that makes every other feature discoverable.
    ///
    /// What is selected here decides which Home cards get placed, which
    /// permissions the next screen asks for, and which targets get seeded. Rows
    /// whose feature flag is off are absent rather than disabled — offering a
    /// choice the build cannot honour is worse than not offering it.
    var modulesStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Modules.title,
                subtitle: OnboardingCopy.Modules.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.modules)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 220 : 156), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                ForEach(Array(viewModel.availableModules.enumerated()), id: \.element.id) { index, module in
                    OnboardingSelectableCard(
                        title: module.title,
                        subtitle: module.blurb,
                        icon: module.symbolName,
                        accentColor: currentVisualTheme.accent,
                        accessibilityID: "onboarding.module.\(module.id)",
                        isSelected: viewModel.selectedModuleIDs.contains(module.id)
                    ) {
                        registerSelection()
                        viewModel.toggleModule(module.id)
                    }
                    .cardEntrance(index: index)
                    // A short wave across the grid, so enabling several reads as
                    // one gesture rather than a series of unrelated taps.
                    .lbRipplePop(trigger: viewModel.selectedModuleIDs.count, index: index)
                }
            }
        }
    }

    // MARK: - Permissions

    var permissionsStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Permissions.title,
                subtitle: OnboardingCopy.Permissions.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.permissions)

            VStack(spacing: spacing.s12) {
                ForEach(Array(viewModel.requestablePermissionKinds.enumerated()), id: \.element.id) { index, kind in
                    permissionRow(kind)
                        .cardEntrance(index: index)
                }
            }

            if viewModel.pointOfUsePermissionKinds.isEmpty == false {
                pointOfUseNote
            }
        }
        .lifeboardConfirmationRipple(trigger: permissionRippleTrigger, tint: currentVisualTheme.accent)
    }

    private func permissionRow(_ kind: LifeBoardPermissionKind) -> some View {
        let isGranted = viewModel.grantedPermissionKinds.contains(kind)
        let isInFlight = viewModel.permissionInFlight == kind

        return HStack(alignment: .top, spacing: spacing.s12) {
            Image(systemName: kind.symbolName)
                .font(.title3)
                .foregroundStyle(currentVisualTheme.accent)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Text(kind.blurb)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: spacing.s8)

            if isGranted {
                Label(OnboardingCopy.Permissions.allowed, systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                    .accessibilityLabel(OnboardingCopy.Permissions.allowed)
            } else if isInFlight {
                ProgressView()
            } else {
                Button(OnboardingCopy.Permissions.allow) {
                    feedbackController.medium()
                    Task {
                        await viewModel.requestPermission(kind)
                        guard motionPolicy.allowsSpatialMotion else { return }
                        permissionRippleTrigger &+= 1
                    }
                }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("onboarding.permission.\(kind.rawValue).allow")
            }
        }
        .padding(spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        .animation(reduceMotion ? nil : LifeBoardAnimation.stateChange, value: isGranted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.permission.\(kind.rawValue)")
    }

    /// Microphone, speech, and camera are named but not requested: iOS asks for
    /// them at the moment they are first used, and priming them here would mean
    /// two dialogs for one action.
    private var pointOfUseNote: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(OnboardingCopy.Permissions.atFirstUse)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)

            HStack(spacing: spacing.s12) {
                ForEach(viewModel.pointOfUsePermissionKinds) { kind in
                    Label(kind.title, systemImage: kind.symbolName)
                        .labelStyle(.titleAndIcon)
                        .lifeboardFont(.caption2)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(spacing.s12)
        .lifeBoardClaySurface(.well)
    }

    // MARK: - Success

    func successView(summary: AppOnboardingSummary) -> some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSuccessHero()
                .accessibilityIdentifier(AppOnboardingAccessibilityID.success)

            OnboardingSuccessSummaryCard(
                areaNames: viewModel.resolvedLifeAreas.map(\.lifeArea.name),
                projectNames: viewModel.resolvedProjects.map(\.project.name),
                habitTitles: summary.createdHabitTitles,
                completedTaskTitle: summary.completedTaskTitle
            )

            OnboardingEvaStatusCard(
                state: summary.evaState,
                assistantName: viewModel.selectedMascotPersona.displayName
            )
        }
        .lbCelebrationBurst(trigger: successBurstTrigger)
    }

    // MARK: - Dock

    @ViewBuilder
    var downloadChrome: some View {
        if viewModel.evaPreparationState.phase == .downloading ||
            viewModel.evaPreparationState.phase == .waitingForCellularConsent ||
            viewModel.evaPreparationState.phase == .deferred {
            if viewModel.step == .guide {
                OnboardingDownloadStatusPill(
                    state: viewModel.evaPreparationState,
                    assistantName: viewModel.selectedMascotPersona.displayName
                )
            } else {
                OnboardingDownloadStatusStrip(
                    state: viewModel.evaPreparationState,
                    assistantName: viewModel.selectedMascotPersona.displayName
                )
            }
        }
    }

    var bottomDock: some View {
        VStack(spacing: spacing.s12) {
            if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.danger)
                    .multilineTextAlignment(.center)
            }

            if isKeyboardEditing == false, let action = floatingPrimaryAction {
                OnboardingFloatingNextButton(action: action, theme: currentVisualTheme)
            }

            dockSecondaryContent
                .frame(maxWidth: layoutClass.isPad ? 520 : .infinity, alignment: .center)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, spacing.s12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.18)
                .ignoresSafeArea()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, spacing.s12)
        .padding(.bottom, max(spacing.s8, 8))
    }

    @ViewBuilder
    var dockSecondaryContent: some View {
        switch viewModel.step {
        case .success where viewModel.evaPreparationState.isReady:
            Button(OnboardingCopy.Success.nextCTA) {
                feedbackController.light()
                viewModel.finishOnboarding()
                onDismissFlow()
            }
            .buttonStyle(.lifeBoardChip)
            .accessibilityIdentifier(AppOnboardingAccessibilityID.breakdownNext)
        default:
            EmptyView()
        }
    }
}
