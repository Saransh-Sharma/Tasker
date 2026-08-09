#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'

# The catalog is UTF-8 and carries non-ASCII copy; see
# check_file_size_guardrails.rb for why the locale cannot be trusted here.
SOURCE_ENCODING = 'UTF-8'

root = File.expand_path('..', __dir__)
catalog = File.join(root, 'LifeBoard', 'Localizable.xcstrings')
snapshot = File.join(__dir__, 'localization-keys.sha256')

abort("error: missing localization catalog: #{catalog}") unless File.file?(catalog)
keys = JSON.parse(File.read(catalog, encoding: SOURCE_ENCODING)).fetch('strings').keys.sort
payload = keys.join("\n") + "\n"
digest = Digest::SHA256.hexdigest(payload)

if ARGV.include?('--print')
  puts payload
  warn "count=#{keys.length}"
  warn "sha256=#{digest}"
  exit 0
end

expected = File.file?(snapshot) ? File.read(snapshot)[/sha256=([0-9a-f]{64})/, 1] : nil
abort("error: missing localization-key snapshot: #{snapshot}") unless expected

if digest == expected
  puts "Localization-key snapshot passed (#{keys.length} keys)."
  exit 0
end

warn 'error: localization keys changed.'
warn "expected=#{expected}"
warn "actual=#{digest}"
warn 'Review localization migration impact, then intentionally update the snapshot.'
exit 1
