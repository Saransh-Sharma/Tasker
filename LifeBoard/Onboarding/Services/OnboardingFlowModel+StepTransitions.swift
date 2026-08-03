import Foundation

/// Transitions for the four steps that write real configuration: the guide, the
/// day shape, the module selection, and the permission screen.
extension OnboardingFlowModel {

    // MARK: - Guide

    func selectChiefOfStaffMascot(_ id: AssistantMascotID) {
        guard selectedMascotID != id else { return }
        selectedMascotID = id
        persistSelectedMascot()
        persistJourney()
    }

    func continueFromGuide() {
        persistSelectedMascot()
        startEvaPreparationInBackgroundIfNeeded()
        step = .dayShape
        errorMessage = nil
        persistJourney()
    }

    // MARK: - Day shape

    /// Writes a real `WorkingHoursProfile` plus the week start.
    ///
    /// Every capacity number, free-window projection, and overload signal reads
    /// this profile, and until now it was only reachable through an unlabelled
    /// slider in the Plan toolbar — so everyone silently ran on a Mon–Fri 9-to-5
    /// assumption. Accepting the prefilled values is one tap and still writes the
    /// profile, so the record exists from day one either way.
    func continueFromDayShape() async {
        isWorking = true
        defer { isWorking = false }

        workspacePreferencesStore.update { preferences in
            preferences.weekStartsOn = dayShape.weekStartsOn
        }

        do {
            try await saveWorkingHours(dayShape.makeProfile())
        } catch {
            // A missing profile falls back to the app default rather than
            // blocking setup — the user can still change it in Plan.
            logOnboardingError(
                event: "onboarding_working_hours_failed",
                message: "Could not save working hours from onboarding",
                fields: ["error": error.localizedDescription]
            )
        }

        step = .modules
        errorMessage = nil
        persistJourney()
    }

    func setDayShapeWeekdayHours(start: Int, end: Int) {
        dayShape.weekdayStartMinute = max(0, min(23 * 60 + 59, start))
        dayShape.weekdayEndMinute = max(dayShape.weekdayStartMinute, min(24 * 60, end))
        persistJourney()
    }

    func setDayShapeWeekendHours(start: Int, end: Int) {
        dayShape.weekendStartMinute = max(0, min(23 * 60 + 59, start))
        dayShape.weekendEndMinute = max(dayShape.weekendStartMinute, min(24 * 60, end))
        persistJourney()
    }

    func setWorksWeekends(_ worksWeekends: Bool) {
        dayShape.worksWeekends = worksWeekends
        persistJourney()
    }

    func setWeekStartsOn(_ weekday: Weekday) {
        dayShape.weekStartsOn = weekday
        persistJourney()
    }

    // MARK: - Modules

    func toggleModule(_ id: String) {
        if selectedModuleIDs.contains(id) {
            selectedModuleIDs.remove(id)
        } else {
            selectedModuleIDs.insert(id)
        }
        errorMessage = nil
        persistJourney()
    }

    /// Writes the Home layout implied by the selection.
    ///
    /// The old fixed layout placed ten cards regardless of what the user had, and
    /// seven of them rendered empty on a fresh install. Deriving the layout here
    /// is what makes the first Home screen show real content.
    func continueFromModules() async {
        isWorking = true
        defer { isWorking = false }

        let placements = OnboardingModuleCatalog.homePlacements(for: selectedModuleIDs)
        do {
            try await saveHomeLayout(
                DashboardLayoutValue(mode: .smart, isDefault: true, placements: placements)
            )
        } catch {
            // The curated default remains in place; Home still works.
            logOnboardingError(
                event: "onboarding_home_layout_failed",
                message: "Could not save the derived Home layout from onboarding",
                fields: ["error": error.localizedDescription]
            )
        }

        step = .firstWin
        errorMessage = nil
        persistJourney()
    }

    // MARK: - First win

    func continueFromFirstWin() async {
        guard canContinueHabitSetup else {
            errorMessage = OnboardingCopy.Error.chooseHabit
            return
        }
        await materializeStarterHabitIfNeeded()
        guard errorMessage == nil else { return }
        guard starterTask != nil else {
            errorMessage = OnboardingCopy.Error.firstTaskMissing
            return
        }
        successSummary = nil
        step = .permissions
        errorMessage = nil
        persistJourney()
    }

    // MARK: - Permissions

    var isPermissionGranted: (LifeBoardPermissionKind) -> Bool {
        { [grantedPermissionKinds] kind in grantedPermissionKinds.contains(kind) }
    }

    /// Runs one permission request. Each row is independent — the screen never
    /// blocks on a refusal, and a refusal here is recorded as a deferral rather
    /// than a decline so the feature may still offer once, in context.
    func requestPermission(_ kind: LifeBoardPermissionKind) async {
        guard permissionInFlight == nil else { return }
        permissionInFlight = kind
        defer { permissionInFlight = nil }

        let domains = kind == .appleHealth
            ? OnboardingModuleCatalog.healthDomains(for: selectedModuleIDs)
            : []
        await LifeBoardPermissionPrimingCoordinator.shared.performRequest(
            kind: kind,
            healthDomains: domains
        )
        grantedPermissionKinds.insert(kind)
        logOnboardingInfo(event: "onboarding_permission_requested", fields: ["kind": kind.rawValue])
        persistJourney()
    }

    func skipPermission(_ kind: LifeBoardPermissionKind) {
        LifeBoardPermissionPromptState.recordOnboardingDeferral(kind)
        logOnboardingInfo(event: "onboarding_permission_deferred", fields: ["kind": kind.rawValue])
        persistJourney()
    }

    func continueFromPermissions() {
        // Anything the user passed over is marked deferred, not declined, so the
        // just-in-time layer may still offer it once at the point of use.
        for kind in requestablePermissionKinds where grantedPermissionKinds.contains(kind) == false {
            LifeBoardPermissionPromptState.recordOnboardingDeferral(kind)
        }
        for kind in pointOfUsePermissionKinds {
            LifeBoardPermissionPromptState.recordOnboardingDeferral(kind)
        }

        if let task = createdTasks.first(where: \.isComplete) ?? createdTasks.first {
            successSummary = buildSummary(completedTask: task)
        }
        step = .success
        errorMessage = nil
        persistJourney()
    }

    // MARK: - Finish

    func finishOnboarding() {
        persistEvaActivationCompletion()
        stateStore.markHandled(outcome: .completed)
    }
}
