#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ruby <<'RUBY'
require "pathname"

root = Pathname.pwd
errors = []

living = [
  root.join("README.md"),
  root.join("PRODUCT_REQUIREMENTS_DOCUMENT.md"),
  root.join("DESIGN.md")
]
%w[product guides architecture calendar habits design life-os].each do |directory|
  living.concat(Dir[root.join("docs", directory, "*.md").to_s].sort.map { |path| Pathname(path) })
end
living << root.join("docs", "README.md")
living.uniq!

errors << "expected 44 living documents, found #{living.length}" unless living.length == 44

metadata = ["Classification", "Audience", "Capability status", "Source authority", "Last verified"]
living.each do |path|
  unless path.file?
    errors << "missing living document: #{path.relative_path_from(root)}"
    next
  end
  text = path.read
  metadata.each do |key|
    yaml_key = key.downcase.tr(" ", "_")
    next if text.match?(/#{Regexp.escape(key)}\s*:/i) || text.match?(/^#{Regexp.escape(yaml_key)}\s*:/i)
    errors << "missing metadata '#{key}': #{path.relative_path_from(root)}"
  end
end

def heading_slugs(text)
  counts = Hash.new(0)
  slugs = []
  text.each_line do |line|
    next unless line =~ /^\#{1,6}\s+(.+?)\s*\#*\s*$/
    value = Regexp.last_match(1).gsub(/`([^`]*)`/, '\\1').downcase
    slug = value.gsub(/<[^>]+>/, "").gsub(/[^\p{L}\p{N}\s_-]/, "").strip.gsub(/\s+/, "-")
    suffix = counts[slug]
    counts[slug] += 1
    slugs << (suffix.zero? ? slug : "#{slug}-#{suffix}")
  end
  slugs.to_set
end

require "set"
headings = {}
living.each { |path| headings[path.cleanpath.to_s] = heading_slugs(path.read) if path.file? }

living.each do |source|
  next unless source.file?
  source.read.scan(/(?<!!)\[[^\]]*\]\(([^)]+)\)/).flatten.each do |raw|
    target = raw.strip.sub(/^</, "").sub(/>$/, "")
    next if target.empty? || target.start_with?("#", "http://", "https://", "mailto:", "app://")
    target = target.split(/\s+["']/, 2).first
    file_part, anchor = target.split("#", 2)
    file_part = file_part.gsub("%20", " ")
    resolved = source.dirname.join(file_part).cleanpath
    unless resolved.exist?
      errors << "broken link in #{source.relative_path_from(root)}: #{target}"
      next
    end
    next if anchor.nil? || anchor.empty? || !resolved.file? || resolved.extname.downcase != ".md"
    available = headings[resolved.to_s] ||= heading_slugs(resolved.read)
    errors << "missing heading in #{source.relative_path_from(root)}: #{target}" unless available.include?(anchor.downcase)
  end
end

deleted = %w[
  PLAN_WEEKLY_PLANNING_WORKSPACE.md REDESIGN_TODO.md clean.md
  docs/todos docs/audits docs/phase-1-life-os-foundation.md
  docs/life-os/DAILY_LOOP_HANDOFF.md docs/life-os/DAILY_LOOP_EXPERIENCE_HANDOFF.md
  docs/life-os/phase-1-4-completion-audit.md docs/life-os/phase-2-adaptive-home.md
  docs/life-os/phase-3-4-implementation.md docs/life-os/roadmap.md
  docs/calendar/risk-register.md docs/calendar/roadmap.md
  docs/habits/risk-register.md docs/habits/roadmap.md
  design-system/tasker/MASTER.md design-system/lifeboard-gamification-v2/MASTER.md
]
deleted.each { |path| errors << "retired path still exists: #{path}" if root.join(path).exist? }
Dir[root.join(".codex", "*todo*.md").to_s, root.join(".flow", "*todo*.md").to_s].each do |path|
  errors << "repository-local feature TODO still exists: #{Pathname(path).relative_path_from(root)}"
end

retired = %w[
  LifeOSFoundationShell LifeBoardAppRouter LifeBoardPlanViews
  JournalKit ReflectionKit TranscriptionKit
  habitResilienceV2Enabled planDestinationV1Enabled starterPacksV1Enabled evaPlanRepairV1Enabled
]
living.each do |path|
  next unless path.file?
  text = path.read
  retired.each { |token| errors << "retired token '#{token}' in #{path.relative_path_from(root)}" if text.include?(token) }
end

catalog_path = root.join("docs/product/FEATURE_CATALOG.md")
catalog = catalog_path.read
required_interfaces = %w[
  home plan track insights eva
  taskDetail habitBoard habitLibrary habitDetail trackerDetail careLibrary health project routine goal
  journalDay journalSearch weeklyReflection notesLibrary note knowledgeFolder planDay planWeek backlog
  focusSession dayClose dayOpen weeklyPlanner weeklyPlanningWorkspace weeklyReview trackHistory wellness
  nutrition fasting insightEvidence healthInsight settings settingsDetail tokenGallery referenceDashboard
  task habit journal note trackerEntry mood hydration medicationEvent routineRun timeBlock
  planAndOrganize calendarAndHealth eva reminders lookAndFeel dataAndHelp lifeManagement llm chats models recovery notices
  activity energy hydration nutrition body workouts sleep fasting
  setupChecklist focusNow lifeSnapshot care tasks routines scheduleCapacity quickCapture compactTimeline
  journal progressReflection fasting goals evaConversation bodyMetric workout sleep movement lifeMoment
  nutritionSummary recentMeal logMeal
  AddTaskIntent OpenEvaChatIntent StartFocusSessionIntent QuickJournalCaptureIntent QuickNoteCaptureIntent
  CreateNoteIntent OpenNoteIntent SearchNotesIntent LogWaterIntent LogWeightIntent LogBodyMetricIntent
  StartFastingTimerIntent EndFastingTimerIntent CreateCountdownIntent RequestLLMIntent CaptureToInboxIntent
  OpenTaskScopeIntent CompleteTaskFromWidgetIntent DeferTaskFromWidgetIntent ResolveBehaviorOccurrenceIntent
]
required_interfaces.uniq.each do |name|
  errors << "feature catalog does not account for '#{name}'" unless catalog.include?(name)
end

flags_source = root.join("LifeBoard/Services/V2FeatureFlags.swift").read
promoted_body = flags_source[/private static let promotedDefaults: \[String: Bool\] = \[(.*?)\n\s*\]/m, 1]
if promoted_body.nil?
  errors << "could not parse V2FeatureFlags.promotedDefaults"
else
  promoted_body.scan(/"([^"]+)"\s*:/).flatten.each do |key|
    errors << "feature catalog does not account for promoted flag '#{key}'" unless catalog.include?(key)
  end
end

authority_requirements = {
  "README.md" => %w[docs/product/FEATURE_CATALOG.md docs/product/PUBLIC_CAPABILITY_MATRIX.md docs/design/MARKETING_SITE_GUIDE.md docs/guides/README.md docs/product/LIFEOS_FUTURE_BLUEPRINT.md],
  "docs/README.md" => %w[product/FEATURE_CATALOG.md product/PUBLIC_CAPABILITY_MATRIX.md design/MARKETING_SITE_GUIDE.md guides/README.md product/LIFEOS_FUTURE_BLUEPRINT.md],
  "docs/product/README.md" => %w[FEATURE_CATALOG.md PUBLIC_CAPABILITY_MATRIX.md ../design/MARKETING_SITE_GUIDE.md ../guides/README.md LIFEOS_FUTURE_BLUEPRINT.md]
}
authority_requirements.each do |relative, links|
  text = root.join(relative).read
  links.each { |link| errors << "#{relative} is missing canonical authority link '#{link}'" unless text.include?(link) }
end

matrix = root.join("docs/product/PUBLIC_CAPABILITY_MATRIX.md").read
%w[life.home.orientation life.structure life.capture life.plan.day life.plan.focus life.plan.recovery life.track.habits life.track.goals-routines life.health life.journal life.knowledge life.insights life.eva life.continuity.icloud life.continuity.surfaces].each do |feature_id|
  errors << "public capability matrix is missing '#{feature_id}'" unless matrix.include?(feature_id)
end

marketing_source = root.join("src/content/marketing.ts").read
app_source = root.join("src/App.tsx").read
errors << "marketing source is missing canonical App Store URL" unless marketing_source.include?("https://apps.apple.com/app/id1574046107")
errors << "marketing source is missing canonical support email" unless marketing_source.include?("support@getlifeboard.app")
errors << "marketing site does not use the public promise" unless app_source.include?("One place to run the life you actually have.")
errors << "marketing site does not present Life OS positioning" unless app_source.include?("Your private Life OS")

if errors.any?
  warn "Documentation guardrail failed (#{errors.length} issue#{errors.length == 1 ? "" : "s"}):"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Documentation guardrail passed for #{living.length} living documents."
RUBY
