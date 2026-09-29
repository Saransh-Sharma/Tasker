#!/usr/bin/env ruby
# frozen_string_literal: true

# Copy inventory (DESIGN.md "Voice and copy").
#
# Lists the text a person reads, one row per literal, and prints the numbers
# the copy rewrite is measured by. Heuristic: it reads literals in UI
# positions (Text, Button, titles, alerts, labels, placeholders, `…Copy`
# constants, switch arms that return prose). It does not compile anything.
#
# Usage:
#   ruby scripts/copy_inventory.rb                       # whole app, summary
#   ruby scripts/copy_inventory.rb LifeBoard/Features/Home
#   ruby scripts/copy_inventory.rb --csv out.csv [paths…] # also write rows
#   ruby scripts/copy_inventory.rb --flagged [paths…]    # print flagged rows

require 'csv'
require 'pathname'
require_relative 'copy_voice_rules'

ROOT = Pathname.new(__dir__).parent
SOURCE_GLOBS = %w[
  LifeBoard/**/*.swift
  LifeBoardWidgets/**/*.swift
  LifeBoardWatch/**/*.swift
  LifeBoardWatchWidgets/**/*.swift
  LifeBoardShareExtension/**/*.swift
  Packages/*/Sources/**/*.swift
].freeze

LIT = '"((?:[^"\\\\\n]|\\\\.)*)"'
# kind => pattern whose first capture is the literal. Order matters: the
# first kind that claims a literal wins.
KINDS = [
  ['button', /\b(?:Button|Toggle|Menu|Link|ShareLink)\(\s*#{LIT}/],
  ['text', /\b(?:Text|Label|LabeledContent|Picker|Stepper)\(\s*(?:verbatim:\s*)?#{LIT}/],
  ['field', /\b(?:TextField|SecureField|TextEditor)\(\s*#{LIT}|\bprompt:\s*(?:Text\()?#{LIT}|\bplaceholder:\s*#{LIT}/],
  ['title', /\.navigationTitle\(\s*#{LIT}|\bSection\(\s*#{LIT}|\b(?:title|headline|eyebrow|header):\s*#{LIT}/],
  ['alert', /\.(?:alert|confirmationDialog)\(\s*#{LIT}|\bmessage:\s*(?:Text\()?#{LIT}/],
  ['a11y-label', /\.accessibilityLabel\(\s*(?:Text\()?#{LIT}|\baccessibilityLabel:\s*#{LIT}/],
  ['a11y-hint', /\.accessibilityHint\(\s*(?:Text\()?#{LIT}|\baccessibilityHint:\s*#{LIT}/],
  ['support', /\b(?:subtitle|detail|footer|body|caption|summary|supportingText|description|hint|emptyTitle|emptyMessage|reason):\s*#{LIT}/],
  ['localized', /String\(localized:\s*#{LIT}|LocalizedStringResource\(\s*#{LIT}/],
  ['constant', /\bstatic\s+(?:let|var)\s+\w+(?:\s*:\s*String)?\s*=\s*#{LIT}/],
  ['returned', /\breturn\s+#{LIT}|\bcase\s+[^:]+:\s*(?:return\s+)?#{LIT}/]
].freeze

# Kinds without an unambiguous position only count when they read as prose.
PROSE_ONLY = %w[constant returned localized support].freeze

BUDGET = {
  'button' => 3, 'title' => 5, 'field' => 3, 'text' => 12, 'alert' => 15,
  'a11y-label' => 6, 'a11y-hint' => 6, 'support' => 10, 'localized' => 12,
  'constant' => 12, 'returned' => 12
}.freeze

MINOR = %w[a an and as at by for in of on or the to with vs via].freeze
PROPER = %w[Eva LifeBoard Apple Health Reminders Calendar iPhone iPad Mac Watch Today Tomorrow
            Someday Inbox Backlog Later Face ID iCloud Siri Shortcuts Spotlight Focus XP
            Home Plan Track Insights Settings Journal OpenAI].freeze

def words(text)
  text.gsub(/\\\([^)]*\)/, 'X').split(/\s+/).reject(&:empty?)
end

def prose?(text)
  text =~ /\A[\p{Lu}‘“"\\]/ && text =~ /\s/
end

def title_case?(text)
  significant = words(text).reject { |w| MINOR.include?(w.downcase) || PROPER.include?(w.gsub(/\W/, '')) }
  significant.size >= 2 && significant.drop(1).all? { |w| w =~ /\A\p{Lu}/ }
end

def flags(kind, text)
  count = words(text).size
  found = []
  found << 'over-budget' if count > BUDGET.fetch(kind, 12)
  found << 'voice-smell' if text =~ CopyVoiceRules::VOICE_SMELL_PATTERN
  found << 'disclaimer' if text =~ CopyVoiceRules::DISCLAIMER_PATTERN
  found << 'ui-jargon' if text =~ CopyVoiceRules::UI_JARGON_PATTERN
  found << 'EVA' if text =~ /\bEVA\b/
  found << 'ascii-ellipsis' if text.include?('...')
  found << 'em-dash' if text =~ /[\p{L}\p{N}.,] ?\u2014 ?[\p{L}\p{N}]/
  found << 'title-case' if %w[button title].include?(kind) && title_case?(text)
  found << 'please' if text =~ /\bplease\b/i
  found
end

args = ARGV.dup
csv_path = (i = args.index('--csv')) ? args.slice!(i, 2).last : nil
show_flagged = args.delete('--flagged')
scopes = args.map { |a| ROOT.join(a).expand_path.to_s }

files = SOURCE_GLOBS.flat_map { |g| Dir.glob(ROOT.join(g).to_s) }.uniq.sort
files.select! { |f| scopes.empty? || scopes.any? { |s| f.start_with?(s) } }
files.reject! { |f| f =~ CopyVoiceRules::PROMPT_FILES || f =~ CopyVoiceRules::NON_UI_FILES || f =~ /Tests?\.swift\z|Preview/ }

rows = []
files.each do |path|
  relative = Pathname.new(path).relative_path_from(ROOT).to_s
  CopyVoiceRules.ui_lines(File.readlines(path, encoding: 'UTF-8')).each do |line, index|
    next if line.strip.start_with?('//', '*', '///') || line =~ CopyVoiceRules::NON_UI_LINE

    claimed = {}
    KINDS.each do |kind, pattern|
      line.scan(pattern).each do |captures|
        text = Array(captures).compact.first
        next if text.nil? || claimed[text] || CopyVoiceRules.machine_string?(text)
        next if PROSE_ONLY.include?(kind) && !prose?(text)

        claimed[text] = true
        rows << { file: relative, line: index + 1, kind: kind, text: text,
                  words: words(text).size, flags: flags(kind, text) }
      end
    end
  end
end

if csv_path
  CSV.open(csv_path, 'w') do |csv|
    csv << %w[file line kind words flags text]
    rows.each { |r| csv << [r[:file], r[:line], r[:kind], r[:words], r[:flags].join(' '), r[:text]] }
  end
  puts "Wrote #{rows.size} rows to #{csv_path}"
end

if show_flagged
  rows.reject { |r| r[:flags].empty? }.each do |r|
    puts "#{r[:file]}:#{r[:line]}\t#{r[:kind]}\t[#{r[:flags].join(', ')}]\t#{r[:text]}"
  end
end

total = rows.size
mean = total.zero? ? 0 : rows.sum { |r| r[:words] } / total.to_f
flag_counts = Hash.new(0)
rows.each { |r| r[:flags].each { |f| flag_counts[f] += 1 } }
by_kind = rows.group_by { |r| r[:kind] }.transform_values(&:size)

puts "Copy inventory#{scopes.empty? ? '' : " (#{args.join(', ')})"}"
puts "  strings            #{total}"
puts "  mean words         #{format('%.2f', mean)}"
puts "  over 10 words      #{rows.count { |r| r[:words] > 10 }}"
puts "  by kind            #{by_kind.sort.map { |k, v| "#{k} #{v}" }.join(' · ')}"
puts "  flags              #{flag_counts.sort.map { |k, v| "#{k} #{v}" }.join(' · ')}"
