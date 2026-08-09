#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'

root = Pathname(__dir__).parent.realpath
snapshot_path = root.join('scripts/frozen-contracts.json')

swift_files = Dir.glob(root.join('{LifeBoard,Packages,LifeBoardWidgets,LifeBoardWatch,LifeBoardWatchWidgets,LifeBoardShareExtension,Shared}/**/*.swift')).sort
swift_sources = swift_files.to_h { |path| [Pathname(path).relative_path_from(root).to_s, File.read(path)] }

quoted_value = /"((?:\\.|[^"\\])*)"/
storage_keys = []
raw_values = []
file_names = []
deep_links = []

swift_sources.each do |relative, source|
  source.scan(/(?:forKey|key)\s*:\s*#{quoted_value}/) { |match| storage_keys << match.first }
  source.scan(/\bcase\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*#{quoted_value}/) { |match| raw_values << match.first }
  source.scan(/\b[A-Za-z_][A-Za-z0-9_]*(?:FileName|Filename|fileName|filename)\s*(?::[^=\n]+)?=\s*#{quoted_value}/) do |match|
    file_names << match.first
  end
  source.scan(/lifeboard:\/\/[^"\s\\]+/) { |value| deep_links << value }
end

router_source = swift_sources.fetch('LifeBoard/Foundation/Navigation/AppRouter.swift')
router_literals = router_source.scan(quoted_value).flatten

model_root = root.join('LifeBoard/Persistence/Resources/TaskModelV3.xcdatamodeld')
abort("error: missing Core Data model root: #{model_root}") unless model_root.directory?

core_data = []
Dir.glob(model_root.join('*.xcdatamodel/contents')).sort.each do |path|
  version = Pathname(path).parent.basename('.xcdatamodel').to_s
  source = File.read(path)
  source.scan(/<entity\s+[^>]*name=['"]([^'"]+)['"][^>]*>/).flatten.each do |entity|
    core_data << "version=#{version}\tentity=#{entity}"
  end
  source.scan(/<entity\s+[^>]*name=['"]([^'"]+)['"][^>]*(?:representedClassName|representedClassName)=['"]([^'"]+)['"][^>]*>/).each do |entity, class_name|
    core_data << "version=#{version}\tentity=#{entity}\tclass=#{class_name}"
  end
  source.scan(/<configuration\s+[^>]*name=['"]([^'"]+)['"][^>]*>(.*?)<\/configuration>/m).each do |configuration, body|
    body.scan(/<memberEntity\s+[^>]*name=['"]([^'"]+)['"]/).flatten.each do |entity|
      core_data << "version=#{version}\tconfiguration=#{configuration}\tentity=#{entity}"
    end
  end
end

contracts = {
  'storage_keys' => storage_keys,
  'coding_and_raw_values' => raw_values,
  'core_data_names' => core_data,
  'app_group_file_names' => file_names,
  'deep_links' => deep_links,
  'app_router_literals' => router_literals
}.transform_values { |values| values.uniq.sort }

summary = contracts.transform_values do |values|
  {
    'count' => values.length,
    'sha256' => Digest::SHA256.hexdigest(values.join("\n") + "\n")
  }
end

if ARGV.include?('--write-snapshot')
  snapshot_path.write(JSON.pretty_generate(summary) + "\n")
  puts "Wrote #{snapshot_path.relative_path_from(root)}"
  exit 0
end

abort("error: missing frozen-contract snapshot: #{snapshot_path}") unless snapshot_path.file?
expected = JSON.parse(snapshot_path.read)
unless summary == expected
  warn 'error: a frozen persisted/string contract changed:'
  summary.each do |name, value|
    next if expected[name] == value

    warn "  #{name}: expected #{expected[name].inspect}, actual #{value.inspect}"
  end
  warn 'Review migration/backward-compatibility impact before intentionally updating scripts/frozen-contracts.json.'
  exit 1
end

puts "Frozen contract sets passed (#{summary.map { |name, value| "#{name}=#{value['count']}" }.join(', ')})."
