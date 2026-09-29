#!/usr/bin/env ruby
# frozen_string_literal: true

# iPad and Mac parity ratchet.
#
# Each rule counts occurrences per file and fails when a file has more than
# its baseline in scripts/platform-parity-baseline.tsv. Existing debt is
# recorded, not forgiven: burn it down and regenerate with --update.
#
# Rules
#   inert-swipe      `.swipeActions` in a file with no `List` — swipe actions
#                    only work on List rows, so these do nothing at all.
#   raw-haptic       A UIKit feedback generator outside the two files allowed to
#                    own one. Everything else plays `Haptic.<intent>`, which
#                    honours Low Power Mode, Reduce Motion and Catalyst.
#   escape-less      A `.cancellationAction` toolbar button with no
#                    `.keyboardShortcut` within six lines — Esc does nothing on
#                    a hardware keyboard or the Mac.
#
# Usage: ruby scripts/check_platform_parity.rb [--update]

require 'pathname'

ROOT = Pathname.new(__dir__).parent
BASELINE = ROOT.join('scripts', 'platform-parity-baseline.tsv')
SOURCES = Dir.glob(ROOT.join('LifeBoard', '**', '*.swift').to_s).sort

HAPTIC_OWNERS = %w[
  Packages/LifeBoardTokens/Sources/LifeBoardTokens/MotionAnimations.swift
  LifeBoard/Features/Onboarding/Services/OnboardingFeedbackController.swift
].freeze

def code_lines(text)
  text.lines.reject { |line| line.strip.start_with?('//', '*') }
end

def count_rules(path)
  text = File.read(path, encoding: 'UTF-8')
  lines = code_lines(text)
  relative = Pathname.new(path).relative_path_from(ROOT).to_s
  counts = Hash.new(0)

  swipes = lines.count { |line| line.include?('.swipeActions(') }
  counts['inert-swipe'] = swipes if swipes.positive? && lines.none? { |line| line =~ /\bList\s*[({]/ }

  unless HAPTIC_OWNERS.include?(relative)
    counts['raw-haptic'] = lines.count { |line| line =~ /UI(Impact|Notification|Selection)FeedbackGenerator\(/ }
  end

  lines.each_with_index do |line, index|
    next unless line.include?('placement: .cancellationAction')

    window = lines[index, 7].join
    counts['escape-less'] += 1 unless window.include?('.keyboardShortcut(')
  end

  counts.reject { |_, value| value.zero? }.transform_keys { |rule| [relative, rule] }
end

current = SOURCES.each_with_object({}) { |path, all| all.merge!(count_rules(path)) }

if ARGV.include?('--update')
  File.write(
    BASELINE,
    "# file\trule\tcount — regenerate with: ruby scripts/check_platform_parity.rb --update\n" +
      current.sort.map { |(file, rule), count| "#{file}\t#{rule}\t#{count}" }.join("\n") + "\n"
  )
  puts "Wrote #{current.size} baseline rows to #{BASELINE.relative_path_from(ROOT)}"
  exit 0
end

baseline = {}
if BASELINE.exist?
  BASELINE.readlines.each do |row|
    next if row.start_with?('#') || row.strip.empty?

    file, rule, count = row.chomp.split("\t")
    baseline[[file, rule]] = count.to_i
  end
end

regressions = current.select { |key, count| count > baseline.fetch(key, 0) }
if regressions.empty?
  improved = baseline.count { |key, count| current.fetch(key, 0) < count }
  puts '✅ Platform parity ratchet passed.' + (improved.positive? ? " #{improved} baseline row(s) can be lowered with --update." : '')
  exit 0
end

puts '❌ Platform parity ratchet: new iPad/Mac parity debt'
regressions.sort.each do |(file, rule), count|
  puts "  #{file}: #{rule} #{count} (baseline #{baseline.fetch([file, rule], 0)})"
end
puts 'See the rule notes at the top of scripts/check_platform_parity.rb.'
exit 1
