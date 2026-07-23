#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
MODEL_ROOT = File.join(ROOT, 'LifeBoard', 'TaskModelV3.xcdatamodeld')
SOURCE_MODEL = 'TaskModelV3_KnowledgeNotes.xcdatamodel'
PLANNING_MODEL = 'TaskModelV3_PlanningCore.xcdatamodel'
TRACK_MODEL = 'TaskModelV3_TrackFoundations.xcdatamodel'

def attribute(name, type, optional: true, default: nil, scalar: nil)
  element = REXML::Element.new('attribute')
  element.add_attribute('name', name)
  element.add_attribute('optional', 'YES') if optional
  element.add_attribute('attributeType', type)
  element.add_attribute('defaultValueString', default.to_s) unless default.nil?
  element.add_attribute('usesScalarValueType', scalar ? 'YES' : 'NO') unless scalar.nil?
  element
end

def entity(name, attributes)
  element = REXML::Element.new('entity')
  element.add_attribute('name', name)
  element.add_attribute('representedClassName', 'NSManagedObject')
  element.add_attribute('syncable', 'YES')
  attributes.each { |item| element.add_element(item) }
  index = element.add_element('fetchIndex', 'name' => "by#{name}ID")
  index.add_element('fetchIndexElement', 'property' => 'id', 'type' => 'Binary', 'order' => 'ascending')
  element
end

def add_attributes(document, entity_name, attributes)
  target = document.root.elements.to_a('entity').find { |item| item.attributes['name'] == entity_name }
  raise "#{entity_name} missing" unless target
  existing = target.elements.to_a('attribute').map { |item| item.attributes['name'] }
  attributes.each { |item| target.add_element(item) unless existing.include?(item.attributes['name']) }
end

def add_cloud_entities(document, entities)
  existing_entities = document.root.elements.to_a('entity').map { |item| item.attributes['name'] }
  entities.each { |item| document.root.add_element(item) unless existing_entities.include?(item.attributes['name']) }
  cloud = document.root.elements.to_a('configuration').find { |item| item.attributes['name'] == 'CloudSync' }
  raise 'CloudSync configuration missing' unless cloud
  members = cloud.elements.to_a('memberEntity').map { |item| item.attributes['name'] }
  entities.each do |item|
    cloud.add_element('memberEntity', 'name' => item.attributes['name']) unless members.include?(item.attributes['name'])
  end
end

def load_model(path)
  REXML::Document.new(File.read(File.join(path, 'contents')))
end

def write_model(path, document)
  FileUtils.mkdir_p(path)
  formatter = REXML::Formatters::Pretty.new(4)
  formatter.compact = true
  File.open(File.join(path, 'contents'), 'w') { |file| formatter.write(document, file); file.write("\n") }
end

planning_path = File.join(MODEL_ROOT, PLANNING_MODEL)
planning = load_model(File.join(MODEL_ROOT, SOURCE_MODEL))
add_attributes(planning, 'TaskDefinition', [
  attribute('planningDayYear', 'Integer 32', scalar: true),
  attribute('planningDayMonth', 'Integer 16', scalar: true),
  attribute('planningDayDay', 'Integer 16', scalar: true),
  attribute('planningDayTimeZoneIdentifier', 'String'),
  attribute('commitmentLevelRaw', 'String', default: 'standard'),
  attribute('availabilityRaw', 'String', default: 'actionable'),
  attribute('planningContextRaw', 'String', default: 'neutral'),
  attribute('availabilityExplanation', 'String'),
  attribute('planningResumeDate', 'Date', scalar: false),
  attribute('planningPinOrder', 'Integer 32', scalar: true)
])
add_attributes(planning, 'Project', [attribute('executionModeRaw', 'String', default: 'parallel')])
add_attributes(planning, 'FocusSession', [
  attribute('timeBlockID', 'UUID', scalar: false),
  attribute('pausedAt', 'Date', scalar: false),
  attribute('accumulatedPauseDuration', 'Double', default: 0, scalar: true),
  attribute('interruptionCount', 'Integer 32', default: 0, scalar: true),
  attribute('actualFocusedDuration', 'Double', default: 0, scalar: true),
  attribute('completionOutcomeRaw', 'String'),
  attribute('energyAfter', 'Integer 16', scalar: true),
  attribute('reflection', 'String')
])
planning_entities = [
  entity('InternalTimeBlock', [
    attribute('id', 'UUID', scalar: false), attribute('title', 'String'),
    attribute('startAt', 'Date', scalar: false), attribute('endAt', 'Date', scalar: false),
    attribute('taskID', 'UUID', scalar: false), attribute('planningContextRaw', 'String', default: 'neutral'),
    attribute('isFixed', 'Boolean', default: 'NO', scalar: true),
    attribute('createdAt', 'Date', scalar: false), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('WorkingHoursProfile', [
    attribute('id', 'UUID', scalar: false), attribute('name', 'String'),
    attribute('intervalsData', 'Binary'), attribute('bufferDuration', 'Double', default: 1800, scalar: true),
    attribute('isDefault', 'Boolean', default: 'NO', scalar: true), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('PlanningMutationReceipt', [
    attribute('id', 'UUID', scalar: false), attribute('source', 'String'), attribute('summary', 'String'),
    attribute('forwardData', 'Binary'), attribute('undoData', 'Binary'), attribute('createdAt', 'Date', scalar: false)
  ])
]
add_cloud_entities(planning, planning_entities)
write_model(planning_path, planning)

track_path = File.join(MODEL_ROOT, TRACK_MODEL)
track = load_model(planning_path)
track_entities = [
  entity('GoalDefinition', [
    attribute('id', 'UUID', scalar: false), attribute('title', 'String'), attribute('typeRaw', 'String'),
    attribute('areaID', 'UUID', scalar: false), attribute('targetValue', 'Double', scalar: true),
    attribute('unitLabel', 'String'), attribute('targetDate', 'Date', scalar: false),
    attribute('isArchived', 'Boolean', default: 'NO', scalar: true),
    attribute('createdAt', 'Date', scalar: false), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('GoalLink', [
    attribute('id', 'UUID', scalar: false), attribute('goalID', 'UUID', scalar: false),
    attribute('sourceTypeRaw', 'String'), attribute('sourceID', 'UUID', scalar: false),
    attribute('createdAt', 'Date', scalar: false)
  ]),
  entity('HabitGroup', [
    attribute('id', 'UUID', scalar: false), attribute('title', 'String'),
    attribute('planningContextRaw', 'String', default: 'neutral'),
    attribute('ordinal', 'Integer 32', default: 0, scalar: true), attribute('createdAt', 'Date', scalar: false)
  ]),
  entity('HabitResiliencePolicy', [
    attribute('id', 'UUID', scalar: false), attribute('habitID', 'UUID', scalar: false),
    attribute('groupID', 'UUID', scalar: false), attribute('offDayKeysData', 'Binary'),
    attribute('recoveryEnabled', 'Boolean', default: 'YES', scalar: true),
    attribute('streakPresentationRaw', 'String', default: 'gradeAndStreak'),
    attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('RoutineDefinition', [
    attribute('id', 'UUID', scalar: false), attribute('title', 'String'),
    attribute('version', 'Integer 32', default: 1, scalar: true),
    attribute('isArchived', 'Boolean', default: 'NO', scalar: true),
    attribute('createdAt', 'Date', scalar: false), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('RoutineStep', [
    attribute('id', 'UUID', scalar: false), attribute('routineID', 'UUID', scalar: false),
    attribute('kindRaw', 'String'), attribute('title', 'String'),
    attribute('ordinal', 'Integer 32', default: 0, scalar: true),
    attribute('duration', 'Double', scalar: true), attribute('isRequired', 'Boolean', default: 'YES', scalar: true),
    attribute('isSkippable', 'Boolean', default: 'NO', scalar: true), attribute('configurationData', 'Binary')
  ]),
  entity('RoutineRun', [
    attribute('id', 'UUID', scalar: false), attribute('routineID', 'UUID', scalar: false),
    attribute('versionSnapshotData', 'Binary'), attribute('statusRaw', 'String'),
    attribute('currentStepID', 'UUID', scalar: false), attribute('startedAt', 'Date', scalar: false),
    attribute('endedAt', 'Date', scalar: false), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('RoutineStepEvent', [
    attribute('id', 'UUID', scalar: false), attribute('runID', 'UUID', scalar: false),
    attribute('stepID', 'UUID', scalar: false), attribute('statusRaw', 'String'),
    attribute('responseData', 'Binary'), attribute('occurredAt', 'Date', scalar: false),
    attribute('idempotencyKey', 'String')
  ]),
  entity('HydrationLog', [
    attribute('id', 'UUID', scalar: false), attribute('amount', 'Double', scalar: true),
    attribute('unitRaw', 'String'), attribute('timestamp', 'Date', scalar: false),
    attribute('note', 'String'), attribute('correctedAt', 'Date', scalar: false)
  ]),
  entity('HydrationTarget', [
    attribute('id', 'UUID', scalar: false), attribute('amount', 'Double', scalar: true),
    attribute('unitRaw', 'String'), attribute('updatedAt', 'Date', scalar: false)
  ]),
  entity('SleepContextRecord', [
    attribute('id', 'UUID', scalar: false), attribute('bedtime', 'Date', scalar: false),
    attribute('wakeTime', 'Date', scalar: false), attribute('perceivedRest', 'Integer 16', scalar: true),
    attribute('interruptionCount', 'Integer 32', default: 0, scalar: true),
    attribute('notes', 'String'), attribute('createdAt', 'Date', scalar: false)
  ]),
  entity('StarterPackInstallation', [
    attribute('id', 'UUID', scalar: false), attribute('packRaw', 'String'),
    attribute('createdIDsData', 'Binary'), attribute('installedAt', 'Date', scalar: false),
    attribute('removedAt', 'Date', scalar: false)
  ])
]
add_cloud_entities(track, track_entities)
write_model(track_path, track)

project = Xcodeproj::Project.open(File.join(ROOT, 'LifeBoard.xcodeproj'))

def group_path(root, components)
  components.reduce(root) do |group, component|
    group.groups.find { |candidate| candidate.display_name == component } || group.new_group(component)
  end
end

def add_source(project, target, group, absolute_path)
  reference = project.files.find { |file| file.real_path.to_s == absolute_path }
  reference ||= group.new_file(absolute_path)
  target.source_build_phase.add_file_reference(reference, true)
end

life_board_group = project.main_group.groups.find { |group| group.display_name == 'LifeBoard' }
tests_group = project.main_group.groups.find { |group| group.display_name == 'LifeBoardTests' }
app_target = project.targets.find { |target| target.name == 'LifeBoard' }
test_target = project.targets.find { |target| target.name == 'LifeBoardTests' }
raise 'Required groups or targets missing' unless life_board_group && tests_group && app_target && test_target

foundation_group = group_path(life_board_group, ['Foundation'])
phase_three_group = group_path(foundation_group, ['PhaseIII'])
phase_four_group = group_path(foundation_group, ['PhaseIV'])
Dir[File.join(ROOT, 'LifeBoard', 'Foundation', 'PhaseIII', '*.swift')].sort.each do |path|
  add_source(project, app_target, phase_three_group, path)
end
Dir[File.join(ROOT, 'LifeBoard', 'Foundation', 'PhaseIV', '*.swift')].sort.each do |path|
  add_source(project, app_target, phase_four_group, path)
end
add_source(
  project,
  test_target,
  tests_group,
  File.join(ROOT, 'LifeBoardTests', 'LifeBoardPlanningTrackFoundationTests.swift')
)

version_group = project.objects.find do |object|
  object.isa == 'XCVersionGroup' && object.display_name == 'TaskModelV3.xcdatamodeld'
end
raise 'TaskModelV3 version group missing' unless version_group

[SOURCE_MODEL, PLANNING_MODEL, TRACK_MODEL].each do |model_name|
  version_group.children.find { |child| child.path == model_name } || version_group.new_file(model_name)
end
version_group.current_version = version_group.children.find { |child| child.path == TRACK_MODEL }
project.save

puts 'Configured Planning Core and Track Foundations model versions.'
