#!/usr/bin/env ruby
# Script to add Presentation layer files to Xcode target's Compile Sources build phase

require 'pathname'

project_file = Pathname.new(__FILE__).dirname + "Tasker.xcodeproj/project.pbxproj"

# File reference IDs for the Presentation files that need to be added
files_to_add = [
  { ref: "6BF3757D8115E83B741E8EDE", name: "HomeViewModel.swift" },
  { ref: "141BE4350B00A5F4A2C2B515", name: "AddTaskViewModel.swift" },
  { ref: "43352D12D85E99E17F153205", name: "ProjectManagementViewModel.swift" },
  { ref: "891EEC99B504A8EE48C2F293", name: "PresentationDependencyContainer.swift" }
]

# Read the project file
content = File.read(project_file)

# Check which files are already in the Sources build phase
already_added = []
files_to_add.each do |file|
  if content.include?("#{file[:ref]} /* #{file[:name]} in Sources */")
    already_added << file[:name]
  end
end

if already_added.length == files_to_add.length
  puts "All files are already in the Sources build phase!"
  puts "Trying a different approach..."

  # Check if files are referenced without "in Sources"
  files_to_add.each do |file|
    pattern = "#{file[:ref]} /* #{file[:name]}"
    if content.include?(pattern) && !content.include?("#{file[:ref]} /* #{file[:name]} in Sources */")
      puts "Found #{file[:name]} but without 'in Sources' suffix"
    end
  end
end

# Find and replace the pattern that ends the Sources build phase
modified = false
lines = content.lines

# Find the closing of Sources build phase and add files before it
(0...lines.length).each do |i|
  line = lines[i]
  # Look for the pattern "\t\t\t\t);\n" that ends the Sources build phase
  if line.strip == ");" && i > 0
    # Check if we're in the Sources build phase by looking back
    lookback = i - 30
    lookback = 0 if lookback < 0

    in_sources = false
    ((lookback)...i).each do |j|
      if lines[j].include?("/* Sources */")
        in_sources = true
        break
      end
      if lines[j].include?("/* Frameworks */")
        break
      end
    end

    if in_sources
      # Check if we're at the right spot (after the last file entry)
      # The line before ); should be a file entry
      prev_line = lines[i-1]
      if prev_line.include?("in Sources */") || prev_line.strip == ","
        # Insert our files
        files_to_add.each do |file|
          next if content.include?("#{file[:ref]} /* #{file[:name]} in Sources */")

          # Insert before the ); line
          lines.insert(i, "\t\t\t\t#{file[:ref]} /* #{file[:name]} in Sources */,\n")
          i += 1  # Adjust index since we inserted a line
          puts "Added: #{file[:name]}"
          modified = true
        end

        # We only want to add to the first Sources build phase we find
        break if modified
      end
    end
  end
end

if modified
  File.write(project_file, lines.join)
  puts "\n✅ Successfully updated project.pbxproj"
  puts "Please clean and rebuild in Xcode"
else
  puts "\n⚠️ No changes made - trying alternative approach..."

  # Alternative: Direct string replacement
  # Find the ending of CoreDataTaskRepository+Domain.swift in Sources and add after it
  search_pattern = "A6B3ED55BF6F55277014F9CB /* CoreDataTaskRepository+Domain.swift in Sources */,\n"
  new_files = files_to_add.map { |f| "\t\t\t\t#{f[:ref]} /* #{f[:name]} in Sources */,\n" }.join

  if content.include?(search_pattern)
    new_content = content.sub(search_pattern, search_pattern + new_files)
    if new_content != content
      File.write(project_file, new_content)
      puts "✅ Successfully added files after CoreDataTaskRepository+Domain.swift"
    else
      puts "⚠️ Files may already be present"
    end
  end
end
