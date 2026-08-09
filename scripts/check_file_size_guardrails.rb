#!/usr/bin/env ruby
# frozen_string_literal: true

# New files must satisfy the target limits. Existing oversized files are
# ratcheted: they may shrink but never grow until they meet the target.
#
# Three metrics, because no single one describes the problem:
#
#   lines        the file total. Navigability.
#   types        top-level declarations in the file. Cohesion — a file with 123
#                types passes any per-type check and is still unreadable.
#   largest      lines in the biggest top-level declaration. This is the one
#                that predicts the `-Onone` launch crash: Debug gives every
#                SwiftUI temporary its own stack slot and inlines computed
#                `some View` properties into their caller's frame, so it is the
#                size of the *type*, not the file, that overflows the 1 MB main
#                stack.
#
# `largest` is why extracting a section into a sibling struct counts as progress
# even though it adds lines to the file: the root type shrinks, which is the
# thing that was failing.

MAX_LINES = 800
MAX_TOP_LEVEL_TYPES = 12
MAX_LARGEST_TYPE_LINES = 400

# Sources are UTF-8 regardless of the caller's locale. CI and local shells here
# run under LC_CTYPE=C, which makes Ruby's default external encoding US-ASCII
# and turns every regex match against a file containing non-ASCII bytes into an
# ArgumentError. Read explicitly so the gate cannot be silenced by a locale.
SOURCE_ENCODING = 'UTF-8'

TYPE_DECLARATION = /^\s*(?:(?:public|internal|private|fileprivate|open|final|nonisolated|@\w+(?:\([^)]*\))?)\s+)*(?:class|struct|enum|protocol|actor|typealias)\s+[A-Za-z_]\w*/
# A top-level declaration starts in column zero and, in this codebase's
# formatting, ends at the next line that is exactly a closing brace in column
# zero. `typealias` has no body and is measured as one line.
TOP_LEVEL_START = /^(?:(?:public|internal|private|fileprivate|open|final|nonisolated|@\w+(?:\([^)]*\))?)\s+)*(?:class|struct|enum|protocol|actor|extension)\s+[A-Za-z_]/
TOP_LEVEL_END = /^\}/

def largest_top_level_span(lines)
  largest = 0
  start = nil
  lines.each_with_index do |line, index|
    if start.nil?
      start = index if TOP_LEVEL_START.match?(line)
    elsif TOP_LEVEL_END.match?(line)
      largest = [largest, index - start + 1].max
      start = nil
    end
  end
  largest
end

root = File.expand_path('..', __dir__)
baseline = File.join(__dir__, 'file-size-baseline.tsv')

limits = {}
if File.file?(baseline)
  File.readlines(baseline, chomp: true, encoding: SOURCE_ENCODING).each do |line|
    next if line.empty? || line.start_with?('#')

    path, max_lines, max_types, max_largest = line.split("\t")
    limits[path] = [
      Integer(max_lines),
      Integer(max_types),
      # Tolerate two-column entries from before `largest` existed.
      max_largest.nil? ? MAX_LARGEST_TYPE_LINES : Integer(max_largest)
    ]
  end
end

violations = []
observations = []

Dir.glob(File.join(root, 'LifeBoard', '**', '*.swift')).sort.each do |file|
  relative = file.delete_prefix("#{root}/")
  lines = File.readlines(file, encoding: SOURCE_ENCODING)
  counts = [
    lines.length,
    lines.count { |line| TYPE_DECLARATION.match?(line) },
    largest_top_level_span(lines)
  ]
  observations << [relative, counts]
  allowed = limits.fetch(relative, [MAX_LINES, MAX_TOP_LEVEL_TYPES, MAX_LARGEST_TYPE_LINES])
  next if counts.zip(allowed).all? { |actual, maximum| actual <= maximum }

  violations << [relative, counts, allowed]
end

if ARGV == ['--print-baseline']
  observations.each do |path, counts|
    next if counts[0] <= MAX_LINES &&
            counts[1] <= MAX_TOP_LEVEL_TYPES &&
            counts[2] <= MAX_LARGEST_TYPE_LINES

    puts [path, *counts].join("\t")
  end
  exit 0
end

if violations.empty?
  puts 'File-size guardrails passed.'
  exit 0
end

warn 'error: file-size ratchet violations:'
violations.each do |path, actual, allowed|
  warn "  #{path}: #{actual[0]} lines / #{actual[1]} types / #{actual[2]} largest type " \
       "(allowed #{allowed[0]} / #{allowed[1]} / #{allowed[2]})"
end
exit 1
