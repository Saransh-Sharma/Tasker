# fn-1.5 Cross-check and validate all documentation

## Description
Cross-check and validate all documentation after updates.

## Validation Commands:
```bash
# File sizes
wc -l README.md TECHNICAL_DEBT.md PRODUCT_REQUIREMENTS_DOCUMENT.md CLAUDE.md

# README internal links
grep -n "\[.*\](.*\.md)" README.md

# Cross-doc references
grep -r "CLAUDE.md\|TECHNICAL_DEBT.md\|PRODUCT_REQUIREMENTS_DOCUMENT.md" *.md

# Verify file paths exist
grep -oE "To Do List/[a-zA-Z/]+\.swift" README.md CLAUDE.md | xargs ls -la 2>&1 | grep -v "No such file"

# LLM mentions
grep -c "LLM\|AI\|Eva\|MLX" README.md PRODUCT_REQUIREMENTS_DOCUMENT.md

# Migration consistency
grep -n "70%\|75%\|60%\|730\|189" *.md
```

## Checks:
1. All docs agree: 730 files, ~70% migrated
2. All internal links valid
3. Cross-doc references valid
4. File paths exist
5. LLM in README, PRD, CLAUDE.md
6. No contradictions
## Acceptance
- [ ] README < 1,500 lines verified
- [ ] TECHNICAL_DEBT < 800 lines verified
- [ ] PRD < 1,200 lines verified
- [ ] CLAUDE.md ~450 lines verified
- [ ] All docs show "730 files, ~70% migrated"
- [ ] grep -c "LLM" > 0 for README and PRD
- [ ] No broken internal links
- [ ] File paths valid (ls check passes)
- [ ] No contradictions (grep for inconsistent %)
- [ ] Migration breakdown in CLAUDE.md
- [ ] Badges present in README
- [ ] Debt summary table present
## Done summary
- File size targets: ALL PASSED (README 226, Debt 147, PRD 225, CLAUDE 458)
- Data consistency: All docs agree on "~70% migrated", 730 files
- LLM coverage: README (8 mentions), PRD (8 mentions), CLAUDE (2 mentions)
- Cross-references: All internal links validated
- Badges present: 6 badges in README (iOS, Swift, Xcode, License, Files, Architecture)
- Migration table: Present in CLAUDE.md with 5 layers
- Debt summary table: Present in TECHNICAL_DEBT.md
- Overall reduction: 10,725 → 1,056 lines (90%)
## Evidence
- Commits:
- Tests: wc -l README.md # 226 lines (96% reduction from 6,012), wc -l TECHNICAL_DEBT.md # 147 lines (90% reduction from 1,517), wc -l PRODUCT_REQUIREMENTS_DOCUMENT.md # 225 lines (92% reduction from 2,754), wc -l CLAUDE.md # 458 lines (enhanced from 442), grep -c 'LLM\|AI\|Eva\|MLX' README.md # 8 mentions, grep -c 'LLM\|AI\|Eva\|MLX' PRODUCT_REQUIREMENTS_DOCUMENT.md # 8 mentions, grep '~70%' *.md # Found in all 4 docs (consistent)
- PRs: