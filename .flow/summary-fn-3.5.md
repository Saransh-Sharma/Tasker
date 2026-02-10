Removed legacy theme API surfaces and enforced no-old-API guardrails.

Completed:
- Eliminated all code references to `ToDoColors`, `ToDoFont`, `.themeChanged`, and LLM appearance enums.
- Converted remaining references/comments to token-based APIs.
- Replaced Helvetica storyboard/font usages.
- Neutralized legacy theme files (`View/Theme/ToDoColors.swift`, `View/Theme/ToDoFont.swift`, `View/FluentUITokenExtensions.swift`) so they no longer define legacy APIs.
- Added domain color bridge extensions to DesignSystem adapters.
