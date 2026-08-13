#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates membership from the Swift compiler's generated `.SwiftFileList`
# inputs. These files are emitted from Xcode's resolved build graph and remain
# authoritative when a project uses filesystem-synchronized groups; no PBX
# object or filename-comment parsing is involved.

require 'pathname'
require 'set'
require 'json'
require 'open3'

root = Pathname(ENV.fetch('LIFEBOARD_ROOT_DIR')).realpath
derived_data = Pathname(ENV.fetch('LIFEBOARD_MEMBERSHIP_DERIVED_DATA')).expand_path
allowlist_path = Pathname(ENV.fetch('LIFEBOARD_TARGET_MEMBERSHIP_ALLOWLIST'))
exclusions_path = Pathname(ENV.fetch('LIFEBOARD_TARGET_MEMBERSHIP_EXCLUSIONS'))

abort("error: missing compilation output: #{derived_data}") unless derived_data.directory?

def read_list(path)
  return Set.new unless path.file?

  path.each_line(chomp: true).each_with_object(Set.new) do |line, values|
    value = line.sub(/#.*/, '').strip
    values << value unless value.empty?
  end
end

allowlisted = read_list(allowlist_path)
excluded = read_list(exclusions_path)
memberships = Hash.new { |hash, key| hash[key] = Set.new }
observed_targets = Set.new
file_lists = Dir.glob(derived_data.join('Build', 'Intermediates.noindex', '**', '*.SwiftFileList')).sort
abort("error: no compiler SwiftFileList inputs found below #{derived_data}") if file_lists.empty?

file_lists.each do |file_list|
  target_build = Pathname(file_list).ascend.find { |path| path.basename.to_s.end_with?('.build') }
  next unless target_build

  target = Pathname(file_list).basename('.SwiftFileList').to_s
  observed_targets << target
  File.foreach(file_list, chomp: true) do |source|
    source_path = Pathname(source).expand_path
    source_path = source_path.realpath if source_path.file?
    next unless source_path.to_s.start_with?("#{root}/")
    next unless source_path.extname == '.swift'

    relative = source_path.relative_path_from(root).to_s
    memberships[relative] << target
  end
end

required_targets = %w[
  LifeBoard LifeBoardTests LifeBoardUITests LifeBoardWidgets LifeBoardShareExtension
  LifeBoardWatch LifeBoardWatchWidgets
]
missing_target_builds = required_targets.reject { |target| observed_targets.include?(target) }

package_json, package_error, package_status = Open3.capture3(
  'swift', 'package', 'dump-package',
  chdir: root.to_s
)
unless package_status.success?
  abort("error: swift package dump-package failed:\n#{package_error}")
end

package_owners = Hash.new { |hash, key| hash[key] = Set.new }
JSON.parse(package_json).fetch('targets').each do |target|
  target_path = root.join(target.fetch('path'))
  next unless target_path.directory?

  excluded = target.fetch('exclude', []).flat_map do |entry|
    path = target_path.join(entry)
    path.directory? ? Dir.glob(path.join('**', '*.swift')) : [path.to_s]
  end.map { |path| Pathname(path).expand_path.to_s }.to_set

  declared_sources = target['sources']
  sources = if declared_sources
              declared_sources.flat_map do |entry|
                path = target_path.join(entry)
                path.directory? ? Dir.glob(path.join('**', '*.swift')) : [path.to_s]
              end
            else
              Dir.glob(target_path.join('**', '*.swift'))
            end

  sources.each do |source|
    source_path = Pathname(source).expand_path
    next unless source_path.file? && source_path.extname == '.swift'
    next if excluded.include?(source_path.to_s)

    relative = source_path.relative_path_from(root).to_s
    package_owners[relative] << target.fetch('name')
  end
end

ambiguous_package_owners = package_owners.select { |_path, owners| owners.length > 1 }
duplicate_package_memberships = package_owners.each_with_object({}) do |(path, owners), duplicates|
  next unless owners.length == 1

  unexpected = memberships[path] - owners
  duplicates[path] = [owners.first, unexpected.to_a.sort] unless unexpected.empty?
end

source_roots = ENV.fetch('LIFEBOARD_SWIFT_SOURCE_ROOTS', '').split(File::PATH_SEPARATOR)
source_roots = %w[LifeBoard LifeBoardTests LifeBoardUITests LifeBoardWatch LifeBoardWatchWidgets LifeBoardWidgets LifeBoardShareExtension Shared Packages] if source_roots.empty?

expected_target = lambda do |relative|
  package_targets = package_owners[relative]
  return package_targets.first if package_targets.length == 1

  case relative
  when %r{\ALifeBoardTests/} then 'LifeBoardTests'
  when %r{\ALifeBoardUITests/} then 'LifeBoardUITests'
  when %r{\ALifeBoardWatchWidgets/} then 'LifeBoardWatchWidgets'
  when %r{\ALifeBoardWatch/} then 'LifeBoardWatch'
  when %r{\ALifeBoardWidgets/} then 'LifeBoardWidgets'
  when %r{\ALifeBoardShareExtension/} then 'LifeBoardShareExtension'
  when %r{\ALifeBoard/} then 'LifeBoard'
  end
end

missing = []
wrong_primary_target = []
source_roots.each do |source_root|
  absolute_root = root.join(source_root)
  next unless absolute_root.directory?

  Dir.glob(absolute_root.join('**', '*.swift')).sort.each do |file|
    next if File.basename(file) == 'Package.swift'

    relative = Pathname(file).relative_path_from(root).to_s
    targets = memberships[relative]
    if targets.empty?
      next if excluded.include?(relative)
      next if allowlisted.include?(relative)

      missing << relative
      next
    end

    expected = expected_target.call(relative)
    next unless expected
    next if targets.include?(expected)

    wrong_primary_target << [relative, expected, targets.to_a.sort]
  end
end

stale_allowlist = allowlisted.select { |path| memberships.key?(path) && !memberships[path].empty? }.sort
unknown_allowlist = allowlisted.reject { |path| root.join(path).file? }.sort
unknown_exclusions = excluded.reject { |path| root.join(path).file? }.sort

unless missing_target_builds.empty?
  warn 'error: required targets did not emit compiler file lists:'
  missing_target_builds.each { |target| warn "  #{target}" }
end
unless ambiguous_package_owners.empty?
  warn 'error: SwiftPM manifest assigns a source to more than one target:'
  ambiguous_package_owners.sort.each do |path, owners|
    warn "  #{path} (#{owners.to_a.sort.join(', ')})"
  end
end
unless duplicate_package_memberships.empty?
  warn 'error: SwiftPM-owned sources also compile in non-owning targets:'
  duplicate_package_memberships.sort.each do |path, (owner, unexpected)|
    warn "  #{path} (owner #{owner}; also #{unexpected.join(', ')})"
  end
end
unless missing.empty?
  warn 'error: Swift files have no compilation-derived target membership:'
  missing.each { |path| warn "  #{path}" }
end
unless wrong_primary_target.empty?
  warn 'error: Swift files compile only in an unexpected target:'
  wrong_primary_target.each do |path, expected, actual|
    warn "  #{path} (expected #{expected}; actual #{actual.join(', ')})"
  end
end
unless stale_allowlist.empty?
  warn 'error: allowlist entries now compile and must be removed:'
  stale_allowlist.each { |path| warn "  #{path}" }
end
unless unknown_allowlist.empty?
  warn 'error: allowlist entries do not exist:'
  unknown_allowlist.each { |path| warn "  #{path}" }
end
unless unknown_exclusions.empty?
  warn 'error: target-membership exclusions do not exist:'
  unknown_exclusions.each { |path| warn "  #{path}" }
end

failed = [
  missing_target_builds,
  ambiguous_package_owners,
  duplicate_package_memberships,
  missing,
  wrong_primary_target,
  stale_allowlist,
  unknown_allowlist,
  unknown_exclusions
].any?(&:any?)
exit 1 if failed

puts "Compilation-derived target membership passed (#{memberships.length} sources, #{observed_targets.length} targets)."
