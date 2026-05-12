#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_FILE="LifeBoard.xcodeproj/project.pbxproj"

if rg -n "/\\* TaskDefinitionEntity\\+CoreDataProperties.swift in Sources \\*/|/\\* ProjectEntity\\+CoreDataProperties.swift in Sources \\*/" "$PROJECT_FILE"; then
  echo "Handwritten Core Data properties files must not be compiled in app target sources"
  exit 1
fi

MODEL_FILES=(
  "LifeBoard/TaskModelV3.xcdatamodeld/TaskModelV3.xcdatamodel/contents"
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
