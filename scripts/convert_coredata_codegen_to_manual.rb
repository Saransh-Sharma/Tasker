#!/usr/bin/env ruby
# frozen_string_literal: true

ENTITY_NAMES = %w[
  ExternalContainerMap HabitDefinition LifeArea ProjectSection ReflectionNote
  Tag TaskDependency TaskTagLink WeeklyOutcome WeeklyPlan WeeklyReview
].freeze

root = File.expand_path('..', __dir__)
model_root = File.join(root, 'LifeBoard', 'Persistence', 'Resources', 'TaskModelV3.xcdatamodeld')
model_files = Dir.glob(File.join(model_root, '*.xcdatamodel', 'contents')).sort
abort("error: expected 23 TaskModelV3 versions, found #{model_files.length}") unless model_files.length == 23

remaining = []
model_files.each do |path|
  source = File.binread(path)
  ENTITY_NAMES.each do |entity_name|
    quoted_name = /(?:"#{Regexp.escape(entity_name)}"|'#{Regexp.escape(entity_name)}')/
    pattern = /<entity\s+name=#{quoted_name}[^>]*>/
    source = source.gsub(pattern) do |entity_tag|
      if ARGV == ['--apply']
        entity_tag.sub(/\s+codeGenerationType=(?:"class"|'class')/, '')
      elsif entity_tag.include?('codeGenerationType=')
        remaining << "#{path.delete_prefix("#{root}/")}:#{entity_name}"
        entity_tag
      else
        entity_tag
      end
    end
    unless ARGV == ['--apply']
      next
    end

    if source.match?(/<entity\s+name=#{quoted_name}[^>]*codeGenerationType=/)
      remaining << "#{path.delete_prefix("#{root}/")}:#{entity_name}"
    end
  end
  File.binwrite(path, source) if ARGV == ['--apply']
end

if ARGV == ['--apply']
  puts "Converted Class Definition entities to Manual/None in #{model_files.length} model versions."
  exit 0
end

unless remaining.empty?
  warn 'error: TaskModelV3 still contains Class Definition entities:'
  remaining.each { |entry| warn "  #{entry}" }
  exit 1
end

puts "Core Data codegen mode check passed (#{model_files.length} model versions)."
