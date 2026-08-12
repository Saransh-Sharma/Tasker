#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ruby - "$ROOT_DIR" <<'RUBY'
root = ARGV.fetch(0)
source_roots = %w[
  LifeBoard
  LifeBoardWidgets
  LifeBoardWatch
  LifeBoardWatchWidgets
  LifeBoardShareExtension
]

intent_description = /IntentDescription\s*\(\s*"((?:\\.|[^"\\])*)"/m
forbidden_term = /\bapple\b/i
violations = []

source_roots.each do |source_root|
  Dir.glob(File.join(root, source_root, "**", "*.swift")).sort.each do |path|
    source = File.read(path)
    source.to_enum(:scan, intent_description).each do
      match = Regexp.last_match
      next unless match[1].match?(forbidden_term)

      line = source.byteslice(0, match.begin(0)).count("\n") + 1
      violations << "#{path.delete_prefix("#{root}/")}:#{line}: #{match[1]}"
    end
  end
end

unless violations.empty?
  warn "App Intent description validation failed. Error 90626 forbids 'apple' in IntentDescription metadata:"
  violations.each { |violation| warn "  #{violation}" }
  exit 1
end

puts "App Intent descriptions passed App Store reserved-word validation."
RUBY
