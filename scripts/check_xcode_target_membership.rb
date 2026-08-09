#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates the declared source membership graph instead of using filename
# substring matches. The parser intentionally reads PBXBuildFile ->
# PBXSourcesBuildPhase -> PBXNativeTarget edges, so duplicate basenames and
# files assigned to the wrong target cannot produce a false pass.

require 'set'

# The project file is UTF-8 and carries non-ASCII in group and file comments.
# Ruby derives its default external encoding from the locale, and CI runs under
# LC_CTYPE=C, which tags the read as US-ASCII and makes every subsequent regex
# operation raise ArgumentError. See scripts/check_file_size_guardrails.rb.
SOURCE_ENCODING = 'UTF-8'

root = ENV.fetch('LIFEBOARD_ROOT_DIR')
project = ENV.fetch('LIFEBOARD_PROJECT_FILE')
allowlist_path = ENV.fetch('LIFEBOARD_TARGET_MEMBERSHIP_ALLOWLIST')
exclusions_path = ENV.fetch('LIFEBOARD_TARGET_MEMBERSHIP_EXCLUSIONS')

abort("error: missing project file: #{project}") unless File.file?(project)

pbx = File.read(project, encoding: SOURCE_ENCODING)
objects = {}
# Xcode normally uses hexadecimal object identifiers, but existing projects
# may contain user-created alphanumeric identifiers. Treat the identifier as
# opaque; the membership graph only needs referential consistency.
pbx.scan(/^\t\t([A-Za-z0-9]+) \/\*.*?\*\/ = \{(.*?)\};$/m) do |identifier, body|
  objects[identifier] = body
end

abort('error: could not parse project objects') if objects.empty?

def scalar(body, key)
  match = body.match(/\b#{Regexp.escape(key)} = ("[^"]*"|[^;]+);/)
  return nil unless match

  match[1]
    .strip
    .sub(/\s+\/\*.*\*\/\z/, '')
    .sub(/^"/, '')
    .sub(/"$/, '')
end

def references(body, key)
  match = body.match(/\b#{Regexp.escape(key)} = \((.*?)\);/m)
  return [] unless match

  match[1].scan(/([A-Za-z0-9]+) \/\*/).flatten
end

records = objects.transform_values do |body|
  {
    isa: scalar(body, 'isa'),
    path: scalar(body, 'path'),
    source_tree: scalar(body, 'sourceTree'),
    name: scalar(body, 'name'),
    file_ref: scalar(body, 'fileRef'),
    children: references(body, 'children'),
    files: references(body, 'files'),
    build_phases: references(body, 'buildPhases')
  }
end

parents = {}
records.each do |identifier, record|
  next unless %w[PBXGroup PBXVariantGroup PBXFileSystemSynchronizedRootGroup].include?(record[:isa])

  record[:children].each { |child| parents[child] = identifier }
end

resolve_path = lambda do |identifier, seen = Set.new|
  return '' if identifier.nil? || seen.include?(identifier)

  seen.add(identifier)
  record = records.fetch(identifier)
  component = record[:path].to_s
  return component if record[:source_tree] == 'SOURCE_ROOT'

  parent = resolve_path.call(parents[identifier], seen)
  return parent if component.empty?
  return component if parent.empty?

  File.join(parent, component)
end

build_file_refs = records.each_with_object({}) do |(identifier, record), result|
  result[identifier] = record[:file_ref] if record[:isa] == 'PBXBuildFile' && record[:file_ref]
end

source_phases = records.select { |_identifier, record| record[:isa] == 'PBXSourcesBuildPhase' }
source_phase_targets = Hash.new { |hash, key| hash[key] = Set.new }

records.each do |_identifier, record|
  next unless record[:isa] == 'PBXNativeTarget'

  target_name = record[:name] || record[:path]
  record[:build_phases].each do |phase|
    source_phase_targets[phase] << target_name if source_phases.key?(phase)
  end
end

memberships = Hash.new { |hash, key| hash[key] = Set.new }
source_phases.each do |phase_identifier, phase|
  phase[:files].each do |build_file|
    file_reference = build_file_refs[build_file]
    next unless file_reference

    path = resolve_path.call(file_reference).sub(%r{\A\./}, '')
    next unless path.end_with?('.swift')

    source_phase_targets[phase_identifier].each { |target| memberships[path] << target }
  end
end

allowlisted = if File.file?(allowlist_path)
                File.readlines(allowlist_path, chomp: true, encoding: SOURCE_ENCODING).map do |line|
                  value = line.sub(/#.*/, '').strip
                  value unless value.empty?
                end.compact.to_set
              else
                Set.new
              end

excluded = if File.file?(exclusions_path)
             File.readlines(exclusions_path, chomp: true, encoding: SOURCE_ENCODING).map do |line|
               value = line.sub(/#.*/, '').strip
               value unless value.empty?
             end.compact.to_set
           else
             Set.new
           end

primary_targets = {
  'LifeBoard' => 'LifeBoard',
  'LifeBoardTests' => 'LifeBoardTests',
  'LifeBoardUITests' => 'LifeBoardUITests',
  'LifeBoardWatch' => 'LifeBoardWatch',
  'LifeBoardWatchWidgets' => 'LifeBoardWatchWidgets',
  'LifeBoardWidgets' => 'LifeBoardWidgets'
}.freeze

source_roots = ENV.fetch('LIFEBOARD_SWIFT_SOURCE_ROOTS', '').split(File::PATH_SEPARATOR)
source_roots = %w[LifeBoard LifeBoardTests LifeBoardUITests LifeBoardWatch LifeBoardWatchWidgets LifeBoardWidgets Shared] if source_roots.empty?

missing = []
wrong_primary_target = []
source_roots.each do |source_root|
  absolute_root = File.join(root, source_root)
  next unless Dir.exist?(absolute_root)

  Dir.glob(File.join(absolute_root, '**', '*.swift')).sort.each do |file|
    relative = file.delete_prefix("#{root}/")
    targets = memberships[relative]
    if targets.empty?
      next if excluded.include?(relative)

      missing << relative unless allowlisted.include?(relative)
      next
    end

    primary_target = primary_targets[source_root]
    if primary_target && !targets.include?(primary_target)
      wrong_primary_target << [relative, primary_target, targets.to_a.sort]
    end
  end
end

allowed_missing = allowlisted.select { |path| memberships[path].empty? && File.file?(File.join(root, path)) }.sort
stale_allowlist = allowlisted.reject { |path| memberships[path].empty? }.sort
unknown_allowlist = allowlisted.reject { |path| File.file?(File.join(root, path)) }.sort
unknown_exclusions = excluded.reject { |path| File.file?(File.join(root, path)) }.sort

unless allowed_missing.empty?
  puts 'Allowed Swift files without declared target membership:'
  allowed_missing.each { |path| puts "  #{path}" }
end

unless stale_allowlist.empty?
  warn 'warning: allowlist entries now have declared target membership and should be removed:'
  stale_allowlist.each { |path| warn "  #{path}" }
end

unless unknown_allowlist.empty?
  warn 'warning: allowlist entries no longer exist and should be removed:'
  unknown_allowlist.each { |path| warn "  #{path}" }
end

unless unknown_exclusions.empty?
  warn 'warning: target-membership exclusions no longer exist and should be removed:'
  unknown_exclusions.each { |path| warn "  #{path}" }
end

unless missing.empty?
  warn 'error: Swift files have no declared target membership:'
  missing.each { |path| warn "  #{path}" }
end

unless wrong_primary_target.empty?
  warn 'error: Swift files are declared only in an unexpected target:'
  wrong_primary_target.each do |path, expected, actual|
    warn "  #{path} (expected #{expected}; actual #{actual.join(', ')})"
  end
end

if missing.empty? && wrong_primary_target.empty?
  puts 'Declared Xcode target membership check passed.'
  exit 0
end

exit 1
