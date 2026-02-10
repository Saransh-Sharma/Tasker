Migrated LLM module appearance to shared design tokens and removed local appearance controls.

Completed:
- Removed LLM-local tint/font appearance storage and enums from `LLM/Models/Data.swift`.
- Replaced LLM SwiftUI `.tint(...)` usage with DesignSystem accent token color.
- Removed local dynamic type overrides from LLM views.
- Replaced Chat host theme NotificationCenter dependency with `TaskerThemeManager.publisher` and token-driven nav bar styling.
- Simplified `AppearanceSettingsView` to reflect global token-managed theming.
