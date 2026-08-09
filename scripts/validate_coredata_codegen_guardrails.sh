#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_FILE="LifeBoard.xcodeproj/project.pbxproj"
PACKAGE_MANIFEST="Package.swift"
MANUAL_CLASSES="LifeBoard/Persistence/Entities/LegacyGeneratedManagedObjects.swift"
CODEGEN_CHECK="scripts/convert_coredata_codegen_to_manual.rb"

for required_file in "$PROJECT_FILE" "$PACKAGE_MANIFEST" "$MANUAL_CLASSES" "$CODEGEN_CHECK"; do
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

if ! rg -n 'name: "LifeBoardPersistence"' "$PACKAGE_MANIFEST" >/dev/null ||
   ! rg -n 'Entities/LegacyGeneratedManagedObjects.swift' "$PACKAGE_MANIFEST" >/dev/null; then
  echo "Manual managed-object classes must compile in LifeBoardPersistence"
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

MODEL_FILES=(
  "LifeBoard/Persistence/Resources/TaskModelV3.xcdatamodeld/TaskModelV3.xcdatamodel/contents"
  "LifeBoard/TaskModelV2.xcdatamodeld/TaskModelV2V3.xcdatamodel/contents"
  "LifeBoard/TaskModelV2.xcdatamodeld/TaskModelV2.xcdatamodel/contents"
)

for model_file in "${MODEL_FILES[@]}"; do
  if ! rg -n '<entity name="Project"[^>]*codeGenerationType="category"[^>]*>' "$model_file" >/dev/null; then
    echo "Project entity must use codeGenerationType=category in $model_file"
    exit 1
  fi

  if ! rg -n '<entity name="TaskDefinition"[^>]*codeGenerationType="category"[^>]*>' "$model_file" >/dev/null; then
    echo "TaskDefinition entity must use codeGenerationType=category in $model_file"
    exit 1
  fi
done
