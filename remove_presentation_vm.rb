require 'xcodeproj'

project_path = 'Tasker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Tasker' }
if target.nil?
  puts "Error: Target 'Tasker' not found"
  exit 1
end

files_to_remove = [
  'To Do List/Presentation/ViewModels/ProjectManagementViewModel.swift',
]

files_to_remove.each do |file_path|
  file_basename = File.basename(file_path)
  build_files = target.source_build_phase.files.select do |bf|
    bf.file_ref && bf.file_ref.path && bf.file_ref.path.end_with?(file_basename)
  end
  
  build_files.each do |bf|
    target.source_build_phase.files.delete(bf)
    puts "Removed #{file_path} from target"
  end
end

project.save
puts "Project saved"
