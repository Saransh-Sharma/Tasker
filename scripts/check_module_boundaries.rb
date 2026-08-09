#!/usr/bin/env ruby
# frozen_string_literal: true

# Uses Swift's parser (`swiftc -frontend -dump-parse`) instead of source-text
# regular expressions. Import declarations are read from the compiler AST and
# validated against the declared internal-target adjacency graph.

require 'open3'
require 'pathname'
require 'set'

root = Pathname(ENV.fetch('LIFEBOARD_ROOT_DIR')).realpath
adjacency_path = Pathname(ENV.fetch('LIFEBOARD_MODULE_ADJACENCY'))
exceptions_path = Pathname(ENV.fetch('LIFEBOARD_MODULE_BOUNDARY_EXCEPTIONS'))

abort("error: missing module adjacency graph: #{adjacency_path}") unless adjacency_path.file?

adjacency = {}
adjacency_path.each_line(chomp: true) do |line|
  next if line.strip.empty? || line.lstrip.start_with?('#')

  module_name, dependencies = line.split("\t", 2)
  abort("error: malformed adjacency row: #{line}") if module_name.to_s.empty?
  abort("error: duplicate adjacency row for #{module_name}") if adjacency.key?(module_name)

  adjacency[module_name] = dependencies.to_s.split(',').reject(&:empty?).to_set
end

internal_modules = adjacency.keys.to_set
exceptions = Set.new
if exceptions_path.file?
  exceptions_path.each_line(chomp: true) do |line|
    value = line.sub(/#.*/, '').strip
    exceptions << value unless value.empty?
  end
end

feature_names = %w[
  Knowledge Journal Track Plan Weekly DailyLoop Tasks Habits Health Nutrition Wellness
  Eva Settings Onboarding Capture Gamification Sync Insights Focus Projects Home
].freeze

def owner_for(relative, feature_names)
  case relative
  when %r{\APackages/[^/]+/Sources/([^/]+)/}
    Regexp.last_match(1)
  when %r{\APackages/(LifeBoardContracts|LifeBoardTokens|LifeBoardUI|LifeBoardDomain)/Sources/}
    Regexp.last_match(1)
  when %r{\ALifeBoard/Features/([^/]+)/}
    feature = Regexp.last_match(1)
    return 'PlanFeature' if feature == 'Inbox'
    return 'LifeBoardCalendar' if feature == 'Calendar'
    return "#{feature}Feature" if feature_names.include?(feature)

    'LifeBoard'
  when %r{\ALifeBoard/Persistence/}
    'LifeBoardPersistence'
  when %r{\ALifeBoard/}
    'LifeBoard'
  end
end

files = []
%w[LifeBoard Packages].each do |source_root|
  directory = root.join(source_root)
  next unless directory.directory?

  files.concat(Dir.glob(directory.join('**', '*.swift')).sort)
end

abort('error: no Swift sources found for module-boundary analysis') if files.empty?

imports_by_file = Hash.new { |hash, key| hash[key] = Set.new }
parse_failures = []

files.each_slice(100) do |slice|
  stdout, stderr, status = Open3.capture3('xcrun', 'swiftc', '-frontend', '-dump-parse', *slice)
  unless status.success?
    parse_failures << stderr
    next
  end

  stdout.each_line do |line|
    match = line.match(/\(import_decl .*?range=\[([^:]+(?:\/[^:]+)*):\d+:\d+ .*? module="([^"]+)"/)
    next unless match

    absolute = Pathname(match[1]).expand_path
    imports_by_file[absolute.to_s] << match[2].split('.').first
  end
end

unless parse_failures.empty?
  warn 'error: Swift parser failed while constructing the import graph:'
  parse_failures.each { |failure| warn failure }
  exit 1
end

violations = []
files.each do |absolute|
  relative = Pathname(absolute).relative_path_from(root).to_s
  owner = owner_for(relative, feature_names)
  next unless owner

  abort("error: no adjacency declaration for #{owner} (#{relative})") unless adjacency.key?(owner)

  imports_by_file[absolute].each do |imported|
    next unless internal_modules.include?(imported)
    next if imported == owner || adjacency.fetch(owner).include?(imported)
    next if exceptions.include?("#{relative}\t#{imported}")

    violations << "#{relative}: #{owner} may not import #{imported}"
  end

  layer = relative.split('/').fetch(-2, '')
  framework_bans = case layer
                   when 'Domain' then %w[CoreData SwiftUI UIKit]
                   when 'Data' then %w[SwiftUI UIKit]
                   when 'UI' then %w[CoreData]
                   else []
                   end
  imports_by_file[absolute].intersection(framework_bans).sort.each do |imported|
    next if exceptions.include?("#{relative}\t#{imported}")

    violations << "#{relative}: #{layer} layer may not import #{imported}"
  end
end

# CoreData is permitted only in Persistence or feature Data folders. This
# remains useful before and after package extraction.
imports_by_file.each do |absolute, imports|
  next unless imports.include?('CoreData')

  relative = Pathname(absolute).relative_path_from(root).to_s
  permitted = relative.match?(%r{\A(?:LifeBoard/Persistence|Packages/[^/]+/Sources/LifeBoardPersistence)/}) ||
              relative.match?(%r{\ALifeBoard/Features/[^/]+/Data/}) ||
              relative.match?(%r{\APackages/[^/]+/Sources/[A-Za-z]+Feature/Data/})
  next if permitted || exceptions.include?("#{relative}\tCoreData")

  violations << "#{relative}: CoreData is outside Persistence or feature Data"
end

unless violations.empty?
  warn 'error: module-boundary violations:'
  violations.uniq.sort.each { |violation| warn "  #{violation}" }
  exit 1
end

puts "Syntax-aware module-boundary check passed (#{files.length} files, #{adjacency.length} modules)."
