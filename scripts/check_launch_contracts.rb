#!/usr/bin/env ruby
# frozen_string_literal: true

# Launch-contract ratchet (DESIGN.md "Launch contracts").
#
# Each rule counts occurrences per file and fails when a file has more than
# its baseline in scripts/launch-contract-baseline.tsv. Existing debt is
# recorded, not forgiven: burn it down and regenerate with --update. A file
# whose count drops below its baseline also fails until the baseline is
# lowered, so progress is locked in rather than silently re-spent.
#
# Rules
#   raw-enum-copy      `rawValue.capitalized` — an enum case name shown to a
#                      person ("Completehabitoccurrence"). Use a display name.
#   legacy-haptic      `HapticFeedback.` — bypasses `MotionPolicy` (Low Power,
#                      Calm). Play a `Haptic` intent instead.
#   raw-animation      An animation curve written inline (`.spring(`,
#                      `.easeInOut`, `.linear(`, `repeatForever` …). Motion
#                      comes from `MotionProfile` / `.lifeBoardMotion`.
#   untyped-link       `NavigationLink(destination:` — skips the router,
#                      restoration and the Journal lock. Push a typed AppRoute.
#   silent-catch       `catch {}` / `catch { return … }` on one line — a
#                      failure that nobody is told about.
#   fixed-detent       `.presentationDetents([.height(` — clips Dynamic Type.
#
# Voice rules (DESIGN.md "Voice and copy"; word lists in copy_voice_rules.rb)
# count matches inside string literals a person can read. Keys, identifiers,
# logging, interpolated code, and LLM prompt files are skipped. They are HARD:
# no baseline, so any match fails unless `CopyVoiceRules::ALLOWED` names the
# file and the reason.
#   voice-smell        therapeutic or filler words ("gentle", "quietly",
#                      "whenever you're ready").
#   disclaimer         reassurance that argues with a worry nobody raised
#                      ("not a verdict", "LifeBoard never").
#   ui-jargon          storage and pipeline terms ("canonical", "evidence").
#   ascii-ellipsis     "..." — write "…".
#   prose-em-dash      an em dash inside a sentence; split it or cut it.
#   eva-caps           "EVA" in copy. The assistant is named by its persona,
#                      "Eva" by default.
#   staged-flag        (hard rule, no baseline) every `stagedFeatureEnabled`
#                      key needs an explicit `promotedDefaults` entry.
#
# Usage: ruby scripts/check_launch_contracts.rb [--update]

require 'pathname'
require_relative 'copy_voice_rules'

ROOT = Pathname.new(__dir__).parent
BASELINE = ROOT.join('scripts', 'launch-contract-baseline.tsv')
SOURCE_GLOBS = %w[
  LifeBoard/**/*.swift
  LifeBoardWidgets/**/*.swift
  LifeBoardWatch/**/*.swift
  LifeBoardWatchWidgets/**/*.swift
  LifeBoardShareExtension/**/*.swift
  Packages/LifeBoardUI/Sources/**/*.swift
].freeze
# Copy lives in every package, so the voice rules read them all; the code
# rules keep their scope (the token package owns the curves and haptics).
VOICE_ONLY_GLOBS = %w[Packages/*/Sources/**/*.swift].freeze
CODE_SOURCES = SOURCE_GLOBS.flat_map { |glob| Dir.glob(ROOT.join(glob).to_s) }.uniq.sort
SOURCES = (CODE_SOURCES + VOICE_ONLY_GLOBS.flat_map { |glob| Dir.glob(ROOT.join(glob).to_s) }).uniq.sort

# The token package owns the curves and the low-level haptic helper; it is
# not scanned, so these owners only matter for files inside the app.
RULES = {
  'raw-enum-copy' => /rawValue\.capitalized/,
  'legacy-haptic' => /\bHapticFeedback\./,
  'raw-animation' => /\.(spring|easeInOut|easeIn|easeOut|linear|bouncy|snappy|smooth|interactiveSpring)\b(?![A-Za-z])|repeatForever/,
  'untyped-link' => /NavigationLink\(destination:/,
  'silent-catch' => /catch\s*\{\s*(return\b[^{}]*)?\}/,
  'fixed-detent' => /\.presentationDetents\(\[\.height\(/
}.freeze

LITERAL_RULES = {
  'voice-smell' => CopyVoiceRules::VOICE_SMELL_PATTERN,
  'disclaimer' => CopyVoiceRules::DISCLAIMER_PATTERN,
  'ui-jargon' => CopyVoiceRules::UI_JARGON_PATTERN,
  'ascii-ellipsis' => CopyVoiceRules::ASCII_ELLIPSIS_PATTERN,
  'prose-em-dash' => /[\p{L}\p{N}.,] ?\u2014 ?[\p{L}\p{N}]/,
  'eva-caps' => /\bEVA\b/
}.freeze
HARD_RULES = LITERAL_RULES.keys.freeze
ALL_RULES = RULES.keys + LITERAL_RULES.keys

def code_lines(text)
  text.lines.reject { |line| line.strip.start_with?('//', '*', '///') }
end

def count_rules(path)
  lines = code_lines(File.read(path, encoding: 'UTF-8'))
  relative = Pathname.new(path).relative_path_from(ROOT).to_s
  counts = {}
  (CODE_SOURCES.include?(path) ? RULES : {}).each do |rule, pattern|
    total = lines.sum { |line| line.scan(pattern).size }
    counts[[relative, rule]] = total if total.positive?
  end
  return counts if relative =~ CopyVoiceRules::PROMPT_FILES || "/#{relative}" =~ CopyVoiceRules::NON_UI_FILES

  literals = CopyVoiceRules.ui_lines(lines).flat_map { |line, _| CopyVoiceRules.ui_literals(line) }
  LITERAL_RULES.each do |rule, pattern|
    next if CopyVoiceRules.allowed?(relative, rule)

    total = literals.sum { |text| text.scan(pattern).size }
    counts[[relative, rule]] = total if total.positive?
  end
  counts
end

current = SOURCES.each_with_object({}) { |path, all| all.merge!(count_rules(path)) }

if ARGV.include?('--update')
  File.write(
    BASELINE,
    "# file\trule\tcount — regenerate with: ruby scripts/check_launch_contracts.rb --update\n" +
      current.reject { |(_, rule), _| HARD_RULES.include?(rule) }
             .sort.map { |(file, rule), count| "#{file}\t#{rule}\t#{count}" }.join("\n") + "\n"
  )
  puts "Wrote #{current.size} baseline rows to #{BASELINE.relative_path_from(ROOT)}"
  exit 0
end

baseline = {}
if BASELINE.exist?
  BASELINE.readlines.each do |row|
    next if row.start_with?('#') || row.strip.empty?

    file, rule, count = row.chomp.split("\t")
    next if HARD_RULES.include?(rule)

    baseline[[file, rule]] = count.to_i
  end
end

# Staged flags ship only when `promotedDefaults` names them. A new staged key
# with no entry is on for every Debug tester and silently off in Release.
flag_sources = Dir.glob(ROOT.join('LifeBoard', 'Services', 'V2FeatureFlags*.swift').to_s)
flag_text = flag_sources.map { |path| File.read(path, encoding: 'UTF-8') }.join("\n")
staged_keys = flag_text.scan(/stagedFeatureEnabled\(\s*key:\s*"([^"]+)"/m).flatten.uniq
promoted_block = flag_text[/promotedDefaults:\s*\[String:\s*Bool\]\s*=\s*\[(.*?)\n\s*\]/m, 1].to_s
promoted_keys = promoted_block.scan(/"([^"]+)":\s*(?:true|false)/).flatten
unpromoted = staged_keys - promoted_keys
unpromoted.sort.each do |key|
  puts "❌ staged-flag: \"#{key}\" has no promotedDefaults entry — decide its Release default explicitly"
end

regressions = current.select { |key, count| count > baseline.fetch(key, 0) }
stale = baseline.select { |key, count| current.fetch(key, 0) < count }

regressions.sort.each do |(file, rule), count|
  puts "❌ #{rule}: #{file} has #{count} (baseline #{baseline.fetch([file, rule], 0)})"
end
stale.sort.each do |(file, rule), count|
  puts "⬇️  #{rule}: #{file} dropped to #{current.fetch([file, rule], 0)} (baseline #{count}) — lower the baseline with --update"
end

totals = ALL_RULES.map { |rule| "#{rule} #{current.sum { |(_, r), c| r == rule ? c : 0 }}" }
puts "Launch contracts: #{totals.join(' · ')}"

exit(regressions.empty? && stale.empty? && unpromoted.empty? ? 0 : 1)
