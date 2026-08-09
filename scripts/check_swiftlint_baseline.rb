#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

# SwiftLint echoes the offending source line, which may carry non-ASCII bytes.
# Under LC_CTYPE=C the captured output is tagged US-ASCII and scanning it raises;
# see check_file_size_guardrails.rb.
SOURCE_ENCODING = 'UTF-8'

root = File.expand_path('..', __dir__)
baseline = File.join(__dir__, 'swiftlint-baseline.txt')
abort("error: missing SwiftLint baseline: #{baseline}") unless File.file?(baseline)

output, _status = Open3.capture2e('swiftlint', 'lint', '--strict', '--quiet', chdir: root)
actual = Hash.new(0)
output.force_encoding(SOURCE_ENCODING).each_line do |line|
  rule = line[/\(([^()]+)\)\s*$/, 1]
  actual[rule] += 1 if rule && line.include?(': error:')
end

expected = File.readlines(baseline, chomp: true, encoding: SOURCE_ENCODING).each_with_object({}) do |line, values|
  next if line.empty? || line.start_with?('#')

  rule, count = line.split("\t", 2)
  values[rule] = Integer(count)
end

if actual == expected
  puts "SwiftLint debt baseline passed (#{actual.values.sum} existing errors)."
  exit 0
end

warn 'error: SwiftLint debt changed.'
warn "expected=#{expected.sort.to_h}"
warn "actual=#{actual.sort.to_h}"
warn 'Fix newly introduced violations or intentionally ratchet the reviewed baseline.'
exit 1
