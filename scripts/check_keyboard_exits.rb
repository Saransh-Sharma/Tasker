#!/usr/bin/env ruby
# frozen_string_literal: true

# DESIGN.md → "Keyboard contract", rule 2: a keyboard without a Return key
# always carries Done. `.padKeyboard(_:)` (LifeBoardUI/KeyboardExits.swift)
# sets the keyboard type and attaches its Done in one call. A bare
# `.keyboardType(.decimalPad)` is the pattern that stranded the keyboard over a
# commit bar in eleven places, so it may not appear anywhere else.

# See check_file_size_guardrails.rb: pin the read encoding so a bare shell's
# US-ASCII default cannot turn an em dash in a comment into a false failure.
SOURCE_ENCODING = 'UTF-8'
PAD_KEYBOARD = /\.keyboardType\(\s*\.(decimalPad|numberPad|phonePad|asciiCapableNumberPad)\s*\)/
ALLOWED = ['Packages/LifeBoardUI/Sources/LifeBoardUI/KeyboardExits.swift'].freeze

root = File.expand_path('..', __dir__)
sources = Dir.glob(File.join(root, 'LifeBoard', '**', '*.swift')) +
          Dir.glob(File.join(root, 'Packages', '*', 'Sources', '**', '*.swift'))

violations = []
sources.sort.each do |file|
  relative = file.delete_prefix("#{root}/")
  next if ALLOWED.include?(relative)

  File.foreach(file, encoding: SOURCE_ENCODING).with_index(1) do |line, number|
    next if line.lstrip.start_with?('//')

    violations << "#{relative}:#{number}: #{line.strip}" if line.match?(PAD_KEYBOARD)
  end
end

if violations.empty?
  puts 'Keyboard-exit guardrails passed.'
  exit 0
end

warn 'error: a keyboard without a Return key needs its Done; use `.padKeyboard(_:)`:'
violations.each { |violation| warn "  #{violation}" }
exit 1
