#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'LifeBoard.xcodeproj')
project = Xcodeproj::Project.open(PROJECT_PATH)

def group_path(root, components)
  components.reduce(root) do |group, component|
    group.groups.find { |candidate| candidate.display_name == component } || group.new_group(component)
  end
end

def add_source(project, target, group, relative_path)
  absolute_path = File.join(ROOT, 'LifeBoard', relative_path)
  reference = project.files.find { |file| file.real_path.to_s == absolute_path }
  reference ||= group.new_file(absolute_path)
  target.source_build_phase.add_file_reference(reference, true)
end

life_board_group = project.main_group.groups.find { |group| group.display_name == 'LifeBoard' }
raise 'LifeBoard group missing' unless life_board_group

app_target = project.targets.find { |target| target.name == 'LifeBoard' }
test_target = project.targets.find { |target| target.name == 'LifeBoardTests' }
raise 'Required targets missing' unless app_target && test_target

foundation_group = group_path(life_board_group, ['Foundation'])
navigation_group = group_path(foundation_group, ['Navigation'])
design_group = group_path(foundation_group, ['Design'])
persistence_group = group_path(foundation_group, ['Persistence'])

add_source(project, app_target, foundation_group, 'Foundation/LifeOSFoundationContracts.swift')
add_source(project, app_target, navigation_group, 'Foundation/Navigation/LifeBoardAppRouter.swift')
add_source(project, app_target, navigation_group, 'Foundation/Navigation/LifeOSFoundationShell.swift')
add_source(project, app_target, design_group, 'Foundation/Design/LifeBoardDaypartTokens.swift')
add_source(project, app_target, design_group, 'Foundation/Design/LifeBoardAtmosphereRenderer.swift')
add_source(project, app_target, design_group, 'Foundation/Design/LifeBoardFoundationGallery.swift')
add_source(project, app_target, persistence_group, 'Foundation/Persistence/DashboardLayoutRepository.swift')

tests_group = project.main_group.groups.find { |group| group.display_name == 'LifeBoardTests' }
raise 'LifeBoardTests group missing' unless tests_group
test_path = File.join(ROOT, 'LifeBoardTests', 'LifeOSFoundationTests.swift')
test_reference = project.files.find { |file| file.real_path.to_s == test_path } || tests_group.new_file(test_path)
test_target.source_build_phase.add_file_reference(test_reference, true)

privacy_path = File.join(ROOT, 'LifeBoard', 'PrivacyInfo.xcprivacy')
privacy_reference = project.files.find { |file| file.real_path.to_s == privacy_path } || life_board_group.new_file(privacy_path)
%w[LifeBoard LifeBoardWidgets LifeBoardWatch LifeBoardWatchWidgets].each do |target_name|
  target = project.targets.find { |candidate| candidate.name == target_name }
  target&.resources_build_phase&.add_file_reference(privacy_reference, true)
end

version_group = project.objects.find do |object|
  object.isa == 'XCVersionGroup' && object.display_name == 'TaskModelV3.xcdatamodeld'
end
raise 'TaskModelV3 version group missing' unless version_group
model_path = 'TaskModelV3_LifeOSFoundation.xcdatamodel'
model_reference = version_group.children.find { |child| child.path == model_path }
model_reference ||= version_group.new_file(model_path)
version_group.current_version = model_reference

project.targets.each do |target|
  target.build_configurations.each do |configuration|
    if target.name.start_with?('LifeBoardWatch')
      configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '26.0'
      configuration.build_settings.delete('IPHONEOS_DEPLOYMENT_TARGET')
    else
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    end
  end
end

project.build_configurations.each do |configuration|
  configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
end

project.files.select { |file| file.display_name == 'GoogleService-Info.plist' }.each(&:remove_from_project)

project.save
puts 'Configured Phase 1 project sources, resources, model version, and deployment targets.'
