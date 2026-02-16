Implemented logging framework/policy standardization across the app:
- Reworked `LoggingService` into a single-line key-value formatter (`ts/lvl/cmp/evt/msg`) with sorted fields.
- Added structured event API (`log(level:component:event:message:fields:...)`) plus `logWarning/logError/logFatal` event wrappers.
- Set default minimum log level to `.warning` and added launch-arg override `-TASKER_VERBOSE_LOGS` for temporary debug verbosity.
- Kept legacy message helpers as compatibility wrappers routed through the standardized formatter (`evt=legacy_message`/`legacy_error`).
- Set Firebase runtime logging to error-only in startup (`FirebaseConfiguration.shared.setLoggerLevel(.error)`).
- Fixed Core Data transformable metadata class names (`[UUID]/[String]` -> `NSArray`) to remove invalid Objective-C type warnings.
- Added guardrails and policy docs:
  - `.swiftlint.yml` custom rule `no_direct_print`
  - `scripts/check-no-print-logs.sh`
  - CI workflow step in `.github/workflows/design-token-law.yml`
  - README logging contract + severity policy section.

Verification performed:
- `./scripts/check-no-print-logs.sh` passes.
- `rg -n "\\b(Swift\\.)?print\\(" "To Do List" -g '*.swift'` returns no matches.
- `rg -n "HOME_DI|HOME_DATA|HOME_UI_MODE|\\[RADAR\\]" "To Do List" -g '*.swift'` returns no matches.

Build verification is pending manual run (sandboxed environment could not complete unrestricted Xcode build).
