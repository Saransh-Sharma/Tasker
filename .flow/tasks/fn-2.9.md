# fn-2.9 Fix empty availableProjects in task selection

## Description
Added fallback to load projects via projectRepository when ViewModel is unavailable. Uses convertDomainProjectToEntity to convert domain models to entities for backwards compatibility, and logs warning when no projects are available for task detail.

## Acceptance
- [x] Add fallback to load projects if viewModel.projects is empty
- [x] Use ProjectRepository to fetch projects and convert via convertDomainProjectToEntity
- [x] Handle empty projects by disabling/hiding project UI in detail view


## Done summary
- Added fallback to load projects via projectRepository when ViewModel is unavailable
- Uses convertDomainProjectToEntity to convert domain models to entities for backwards compatibility
- Logs warning when no projects are available for task detail

**Why:**
- availableProjects was always empty because ViewModel code was commented out
- Task detail view needs projects for project selection UI

**Verification:**
- Code review confirms projects are fetched and converted correctly
## Evidence
- Commits: eb8887c2bba6baa2318bc23b0b36c6fdd811b6fa
- Tests:
- PRs: