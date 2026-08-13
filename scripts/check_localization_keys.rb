#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'set'

# Catalogs are UTF-8 and carry non-ASCII copy; see
# check_file_size_guardrails.rb for why the locale cannot be trusted here.
SOURCE_ENCODING = 'UTF-8'

def canonical(value)
  case value
  when Hash
    value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
  when Array
    value.map { |element| canonical(element) }
  else
    value
  end
end

root = File.expand_path('..', __dir__)
snapshot = File.join(__dir__, 'localization-keys.sha256')
catalogs = (
  Dir.glob(File.join(root, 'LifeBoard', '**', '*.xcstrings')) +
  Dir.glob(File.join(root, 'Packages', '**', '*.xcstrings'))
).uniq.sort

abort('error: no localization catalogs found under LifeBoard/ or Packages/.') if catalogs.empty?

strings = {}
owners = {}
source_languages = Set.new

catalogs.each do |catalog|
  relative = catalog.delete_prefix("#{root}/")
  data = JSON.parse(File.read(catalog, encoding: SOURCE_ENCODING))
  source_language = data['sourceLanguage']
  source_languages << source_language if source_language

  data.fetch('strings').each do |key, entry|
    if owners.key?(key)
      abort("error: localization key #{key.inspect} is duplicated in #{owners.fetch(key)} and #{relative}")
    end
    owners[key] = relative
    strings[key] = entry
  end
end

keys = strings.keys.sort
key_payload = keys.join("\n") + "\n"
key_digest = Digest::SHA256.hexdigest(key_payload)
content_payload = JSON.generate(canonical(
  'sourceLanguages' => source_languages.to_a.sort,
  'strings' => strings
))
content_digest = Digest::SHA256.hexdigest(content_payload)

if ARGV.include?('--print')
  puts key_payload
  warn "catalogs=#{catalogs.length}"
  warn "count=#{keys.length}"
  warn "sha256=#{key_digest}"
  warn "content_sha256=#{content_digest}"
  exit 0
end

snapshot_contents = File.file?(snapshot) ? File.read(snapshot, encoding: SOURCE_ENCODING) : nil
abort("error: missing localization snapshot: #{snapshot}") unless snapshot_contents

expected_keys = snapshot_contents[/^sha256=([0-9a-f]{64})$/, 1]
expected_content = snapshot_contents[/^content_sha256=([0-9a-f]{64})$/, 1]
abort("error: missing localization-key digest in #{snapshot}") unless expected_keys
abort("error: missing localization-content digest in #{snapshot}") unless expected_content

if key_digest == expected_keys && content_digest == expected_content
  puts "Localization catalog snapshot passed (#{keys.length} keys, #{catalogs.length} catalogs)."
  exit 0
end

warn 'error: localization keys or translations changed.'
warn "expected_keys=#{expected_keys}"
warn "actual_keys=#{key_digest}"
warn "expected_content=#{expected_content}"
warn "actual_content=#{content_digest}"
warn 'Review localization migration impact, then intentionally update the snapshot.'
exit 1
