# Home Primary Widget Rail TODO

- [x] Replace stacked Focus Now and Weekly Operating Layer home modules with a horizontal primary-widget rail.
- [x] Add a default-selection policy that prefers Focus Now and resets when the chosen widget disappears.
- [x] Use a localized UIKit pager bridge for snap paging while keeping SwiftUI as the owner of Home composition.
- [x] Add unit coverage for widget eligibility and default-selection behavior.
- [x] Add UI coverage and page-object helpers for the new rail interaction.

## Home Simplification Follow-up

- [x] Remove the weekly peer-widget rail from Home and restore Focus Now as the only full above-the-fold module.
- [x] Move weekly planning/review into a compact secondary "This week" entry row after the visible Today task block.
- [x] Merge Home habits, recovery, and quiet-tracking surfaces into one lightweight summary row.
- [x] Compress top chrome momentum into one inline status string plus a hairline progress bar.
- [x] Expose quiet-tracking day shortcut selection through accessibility and stabilize the sheet UI test.
