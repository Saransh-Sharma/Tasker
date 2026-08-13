#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_FILE="LifeBoard.xcodeproj/project.pbxproj"
PACKAGE_MANIFEST="Package.swift"
MANUAL_CLASSES="LifeBoard/Persistence/Entities/LegacyGeneratedManagedObjects.swift"
TASK_PROPERTIES="LifeBoard/Persistence/Entities/TaskDefinitionEntity+CoreDataProperties.swift"
PROJECT_PROPERTIES="LifeBoard/Persistence/Entities/ProjectEntity+CoreDataProperties.swift"
CODEGEN_CHECK="scripts/convert_coredata_codegen_to_manual.rb"

for required_file in "$PROJECT_FILE" "$PACKAGE_MANIFEST" "$MANUAL_CLASSES" "$TASK_PROPERTIES" "$PROJECT_PROPERTIES" "$CODEGEN_CHECK"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing Core Data guardrail input: $required_file"
    exit 1
  fi
done

ruby "$CODEGEN_CHECK"

MANUAL_OBJC_NAMES=(
  ExternalContainerMap HabitDefinition LifeAreaEntity ProjectSectionEntity
  ReflectionNoteEntity TagEntity TaskDependency TaskTagLink WeeklyOutcomeEntity
  WeeklyPlanEntity WeeklyReviewEntity
)

for class_name in "${MANUAL_OBJC_NAMES[@]}"; do
  if ! rg -n "@objc\\($class_name\\)" "$MANUAL_CLASSES" >/dev/null; then
    echo "Missing manual managed-object class for Objective-C name $class_name"
    exit 1
  fi
done

if ! swift package dump-package | ruby -rjson -e '
  package = JSON.parse(STDIN.read)
  target = package.fetch("targets").find { |candidate| candidate.fetch("name") == "LifeBoardPersistence" }
  exit 1 unless target && target.fetch("path") == "LifeBoard/Persistence" && target.fetch("exclude").empty?
'; then
  echo "LifeBoardPersistence must own the complete Persistence source tree"
  exit 1
fi

if rg -n '/\* LegacyGeneratedManagedObjects.swift in Sources \*/|/\* TaskModelV3\.xcdatamodeld in Sources \*/' "$PROJECT_FILE"; then
  echo "Package-owned managed-object classes/model must not compile in the app target"
  exit 1
fi

if rg -n "/\\* TaskDefinitionEntity\\+CoreDataProperties.swift in Sources \\*/|/\\* ProjectEntity\\+CoreDataProperties.swift in Sources \\*/" "$PROJECT_FILE"; then
  echo "Handwritten Core Data properties files must not be compiled in app target sources"
  exit 1
fi

MODEL_FILES=(LifeBoard/Persistence/Resources/TaskModelV3.xcdatamodeld/*.xcdatamodel/contents)
if [[ "${#MODEL_FILES[@]}" -ne 23 ]]; then
  echo "Expected 23 packaged TaskModelV3 versions, found ${#MODEL_FILES[@]}"
  exit 1
fi

for model_file in "${MODEL_FILES[@]}"; do
  if rg -n '<entity name=("Project"|'\''Project'\'')[^>]*codeGenerationType=' "$model_file" >/dev/null; then
    echo "Project entity must use Manual/None code generation in $model_file"
    exit 1
  fi

  if rg -n '<entity name=("TaskDefinition"|'\''TaskDefinition'\'')[^>]*codeGenerationType=' "$model_file" >/dev/null; then
    echo "TaskDefinition entity must use Manual/None code generation in $model_file"
    exit 1
  fi
done
