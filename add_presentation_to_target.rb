#!/usr/bin/env ruby
# Safe script to add Presentation files to Xcode target's Sources build phase

project_file = File.expand_path("../Tasker.xcodeproj/project.pbxproj", __FILE__)

# File reference IDs (from Xcode project)
files_to_add = [
  { ref: "6BF3757D8115E83B741E8EDE", name: "HomeViewModel.swift" },
  { ref: "141BE4350B00A5F4A2C2B515", name: "AddTaskViewModel.swift" },
  { ref: "43352D12D85E99E17F153205", name: "ProjectManagementViewModel.swift" },
  { ref: "891EEC99B504A8EE48C2F293", name: "PresentationDependencyContainer.swift" }
]

# Read the project file
content = File.read(project_file)

# Find the last file entry in Sources build phase and append our files
# Pattern: Find "A6B3ED55BF6F55277014F9CB /* CoreDataTaskRepository+Domain.swift in Sources */"
search_pattern = "A6B3ED55BF6F55277014F9CB /* CoreDataTaskRepository+Domain.swift in Sources */,\n"

new_entries = files_to_add.map { |f|
  "\t\t\t\t#{f[:ref]} /* #{f[:name]} in Sources */,\n"
}.join

if content.include?(search_pattern)
  new_content = content.sub(search_pattern, search_pattern + new_entries)

  if new_content != content
    File.write(project_file, new_content)
    puts "✅ Successfully added Presentation files to build phase"
    puts "Added:"
    files_to_add.each { |f| puts "  - #{f[:name]}" }
  else
    puts "⚠️ Files may already be in build phase"
  end
else
  puts "❌ Could not find insertion point in build phase"
  puts "The project structure may have changed."
end
