#!/usr/bin/env ruby
# frozen_string_literal: true

# New production directories should not become collections of tiny fragments.
# Existing candidates are ratcheted: they may not gain files and their average
# source size may not decrease. A focused decomposition may update this
# reviewed baseline only after the directory is no longer a candidate.

MIN_FILES = 8
MIN_AVERAGE_LINES = 150.0
EPSILON = 0.001

# See check_file_size_guardrails.rb: LC_CTYPE=C makes Ruby read sources as
# US-ASCII. Line counting survives that, but the reads are pinned anyway so a
# later change to this script cannot reintroduce the failure.
SOURCE_ENCODING = 'UTF-8'

root = File.expand_path('..', __dir__)
baseline_path = File.join(__dir__, 'directory-shrapnel-baseline.tsv')

baseline = {}
if File.file?(baseline_path)
  File.readlines(baseline_path, chomp: true, encoding: SOURCE_ENCODING).each do |line|
    next if line.empty? || line.start_with?('#')

    path, file_count, minimum_average = line.split("\t", 3)
    baseline[path] = [Integer(file_count), Float(minimum_average)]
  end
end

directories = Hash.new { |hash, key| hash[key] = [] }
Dir.glob(File.join(root, 'LifeBoard', '**', '*.swift')).sort.each do |file|
  directories[file.delete_prefix("#{root}/").then { |path| File.dirname(path) }] <<
    File.foreach(file, encoding: SOURCE_ENCODING).count
end

observations = directories.transform_values do |lengths|
  [lengths.length, lengths.sum.fdiv(lengths.length)]
end

if ARGV == ['--print-baseline']
  observations.sort.each do |path, (file_count, average)|
    next unless file_count >= MIN_FILES && average < MIN_AVERAGE_LINES

    puts [path, file_count, format('%.6f', average)].join("\t")
  end
  exit 0
end

violations = []
observations.each do |path, (file_count, average)|
  current_candidate = file_count >= MIN_FILES && average < MIN_AVERAGE_LINES
  allowed = baseline[path]

  if allowed
    max_files, minimum_average = allowed
    if file_count > max_files || average + EPSILON < minimum_average
      violations << [path, file_count, average, max_files, minimum_average]
    end
  elsif current_candidate
    violations << [path, file_count, average, MIN_FILES - 1, MIN_AVERAGE_LINES]
  end
end

if violations.empty?
  puts 'Directory shrapnel ratchet passed.'
  exit 0
end

warn 'error: directory shrapnel ratchet violations:'
violations.sort.each do |path, files, average, allowed_files, allowed_average|
  warn format('  %s: %d files / %.1f avg LOC (allowed %d files / %.1f avg LOC)', path, files, average, allowed_files, allowed_average)
end
exit 1
