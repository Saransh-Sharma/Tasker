require 'xcodeproj'

project_path = 'Tasker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Tasker' }
if target.nil?
  puts "Error: Target 'Tasker' not found"
  exit 1
end

base_path = File.expand_path(File.dirname(project_path))
file_path = 'To Do List/Domain/Interfaces/CacheServiceProtocol.swift'
abs_path = File.join(base_path, file_path)

file_ref = project.reference_for_path(abs_path)

if file_ref.nil?
  group = project.main_group
  parts = file_path.split('/')
  
  parts[0..-2].each do |part|
    existing_group = group.children.find { |child| child.display_name == part && child.is_a?(Xcodeproj::Project::Object::PBXGroup) }
    if existing_group
      group = existing_group
    else
      group = group.new_group(part, part)
    end
  end
  
  file_ref = group.new_file(abs_path)
end

unless target.source_build_phase.files_references.include?(file_ref)
  target.add_file_references([file_ref])
  puts "Added #{file_path}"
else
  puts "Skipped #{file_path} (already in target)"
end

project.save
puts "Project saved successfully"
