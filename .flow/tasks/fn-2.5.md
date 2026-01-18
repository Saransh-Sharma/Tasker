# fn-2.5 Make AddTaskViewController viewModel optional

## Description
TBD

## Acceptance
- [ ] Change var viewModel: AddTaskViewModel! to optional AddTaskViewModel?
- [ ] Update all usages to use optional chaining (viewModel?)
- [ ] Or add requireViewModel accessor with fatalError for nil case


## Done summary
- Changed viewModel from AddTaskViewModel! to AddTaskViewModel?
- Added documentation comment explaining the optional type is needed while ViewModel path is disabled
- All existing usages already handle optionality correctly (nil checks, optional binding)

**Why:**
- Implicitly unwrapped optional would crash on access when ViewModel is nil

**Verification:**
- Code review confirms change is safe and all usages handle optionality
## Evidence
- Commits: 3925e8b39c471306dc8217c4515fb2258b9604cb
- Tests:
- PRs: