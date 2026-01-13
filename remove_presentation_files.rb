require 'xcodeproj'

project_path = 'Tasker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Tasker' }
if target.nil?
  puts "Error: Target 'Tasker' not found"
  exit 1
end

# Files to remove
files_to_remove_patterns = [
  'InMemoryCacheService.swift',
  'HomeViewModel.swift',
  'AddTaskViewModel.swift',
  'PresentationDependencyContainer.swift'
]

removed_count = 0

files_to_remove_patterns.each do |pattern|
  build_files = target.source_build_phase.files.select do |bf|
    bf.file_ref && bf.file_ref.path && bf.file_ref.path.include?(pattern)
  end
  
  build_files.each do |bf|
    target.source_build_phase.files.delete(bf)
    puts "Removed #{pattern} from target"
    removed_count += 1
  end
end

project.save
puts "Project saved. Removed #{removed_count} files from target."
