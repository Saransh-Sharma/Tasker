#!/usr/bin/env python3

"""
Script to remove references to deleted TaskManager.swift and ProjectManager.swift
from the Xcode project file.
"""

import re
import os

def fix_xcode_project():
    project_file = "/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcodeproj/project.pbxproj"
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔧 Fixing Xcode project references...")
    
    # Remove TaskManager.swift references
    # Remove PBXBuildFile entries
    content = re.sub(r'\s*75F18108245CA229004D9A69 /\* TaskManager\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 75F18107245CA229004D9A69 /\* TaskManager\.swift \*/; \};\n', '', content)
    
    # Remove PBXFileReference entries
    content = re.sub(r'\s*75F18107245CA229004D9A69 /\* TaskManager\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = TaskManager\.swift; sourceTree = "<group>"; \};\n', '', content)
    
    # Remove from children arrays
    content = re.sub(r'\s*75F18107245CA229004D9A69 /\* TaskManager\.swift \*/,\n', '', content)
    
    # Remove from Sources build phase
    content = re.sub(r'\s*75F18108245CA229004D9A69 /\* TaskManager\.swift in Sources \*/,\n', '', content)
    
    # Remove ProjectManager.swift references
    # Remove PBXBuildFile entries
    content = re.sub(r'\s*758D4D7824A93FB300AB57A8 /\* ProjectManager\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 758D4D7724A93FB300AB57A8 /\* ProjectManager\.swift \*/; \};\n', '', content)
    
    # Remove PBXFileReference entries
    content = re.sub(r'\s*758D4D7724A93FB300AB57A8 /\* ProjectManager\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = ProjectManager\.swift; sourceTree = "<group>"; \};\n', '', content)
    
    # Remove from children arrays
    content = re.sub(r'\s*758D4D7724A93FB300AB57A8 /\* ProjectManager\.swift \*/,\n', '', content)
    
    # Remove from Sources build phase
    content = re.sub(r'\s*758D4D7824A93FB300AB57A8 /\* ProjectManager\.swift in Sources \*/,\n', '', content)
    
    # Write the fixed content back
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Xcode project file fixed!")
    print("📝 Removed references to:")
    print("   - TaskManager.swift")
    print("   - ProjectManager.swift")
    print("\n🚀 You can now build the project successfully!")

if __name__ == "__main__":
    fix_xcode_project()
