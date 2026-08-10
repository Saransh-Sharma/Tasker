#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'

# See check_file_size_guardrails.rb: LC_CTYPE=C makes Ruby read sources as
# US-ASCII, and string scanning over invalid bytes is undefined at best.
SOURCE_ENCODING = 'UTF-8'

root = File.expand_path('..', __dir__)
snapshot = File.join(__dir__, 'accessibility-identifiers.sha256')

def invocation_arguments(source)
  values = []
  cursor = 0
  token = '.accessibilityIdentifier'

  while (start = source.index(token, cursor))
    open = source.index('(', start + token.length)
    break unless open

    depth = 0
    quote = nil
    escaped = false
    index = open
    while index < source.length
      character = source[index]
      if quote
        if escaped
          escaped = false
        elsif character == '\\'
          escaped = true
        elsif character == quote
          quote = nil
        end
      elsif character == '"' || character == "'"
        quote = character
      elsif character == '('
        depth += 1
      elsif character == ')'
        depth -= 1
        break if depth.zero?
      end
      index += 1
    end

    break unless depth.zero?

    values << source[(open + 1)...index].gsub(/\s+/, ' ').strip
    cursor = index + 1
  end

  values
end

# `Packages/` is scanned as well as `LifeBoard/`.
#
# The 646 identifiers are a UI-test contract, and moving a view into a package
# must not quietly drop its identifiers out of the snapshot. Scanning only
# `LifeBoard/**` meant every extraction *reduced* the covered set while leaving
# the digest looking merely "changed" — indistinguishable from someone editing
# an identifier on purpose.
sources = Dir.glob(File.join(root, 'LifeBoard', '**', '*.swift')) +
          Dir.glob(File.join(root, 'Packages', '*', 'Sources', '**', '*.swift'))

expressions = sources.flat_map do |file|
  invocation_arguments(File.read(file, encoding: SOURCE_ENCODING))
end.sort.uniq

payload = expressions.join("\n") + "\n"
digest = Digest::SHA256.hexdigest(payload)

if ARGV.include?('--print')
  puts payload
  warn "count=#{expressions.length}"
  warn "sha256=#{digest}"
  exit 0
end

# Pinned like every other read in this script: the note in the snapshot
# contains non-ASCII, and LC_CTYPE=C otherwise makes this a hard crash.
expected = File.file?(snapshot) ? File.read(snapshot, encoding: SOURCE_ENCODING)[/sha256=([0-9a-f]{64})/, 1] : nil
abort("error: missing accessibility snapshot: #{snapshot}") unless expected

if digest == expected
  puts "Accessibility identifier snapshot passed (#{expressions.length} expressions)."
  exit 0
end

warn 'error: accessibility identifier expressions changed.'
warn "expected=#{expected}"
warn "actual=#{digest}"
warn 'Review the identifier and UI-test contract, then intentionally update the snapshot.'
exit 1
