platform :ios, '16.0'
inhibit_all_warnings!

target 'Tasker' do
  use_frameworks!


  # Firebase
  pod 'Firebase/Analytics',   '~> 11.13'
  pod 'Firebase/Crashlytics', '~> 11.13'
  pod 'Firebase/Performance', '~> 11.13'

  # UI / utils
  pod 'SemiModalViewController', '~> 1.0.1'
  pod 'CircleMenu',              '~> 4.1.0'
  pod 'MaterialComponents',      '~> 124.2'
  pod 'ViewAnimator',            '~> 3.1'     # latest; no :modular_headers needed
  pod 'Timepiece',               '~> 1.3.1'
  pod 'FSCalendar',              '~> 2.8.1'
  pod 'EasyPeasy',               '~> 1.9.0'
  pod 'BEMCheckBox',             '~> 1.4.1'
  pod 'DGCharts',                '~> 5.1'
  pod 'TinyConstraints',         '~> 4.0.1'
  pod 'MicrosoftFluentUI', '~> 0.34.0'
  pod 'FluentIcons', '~> 1.1.302' # Added FluentIcons pod


  target 'TaskerTests' do
    inherit! :search_paths
  end

  target 'TaskerUITests' do
    # UI tests need access to frameworks used by the main app
    # Change from :search_paths to :complete to inherit all dependencies
    inherit! :complete
  end
end          # ← closes the outer 'Tasker' block

# Runs after pods project is generated
post_install do |installer|
  warning_phase_names = [
    'Create Symlinks to Header Folders',
    '[CP-User] Optimize resource bundle'
  ]
  toolchain_swift_path = '${TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}'

  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      c.build_settings['SWIFT_SUPPRESS_WARNINGS'] = 'YES'
      c.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
      c.build_settings['TOOLCHAIN_DIR'] = '$(DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain'

      ldflags = Array(c.build_settings['OTHER_LDFLAGS']).flatten.compact.map(&:to_s).uniq
      c.build_settings['OTHER_LDFLAGS'] = ldflags unless ldflags.empty?

      search_paths = Array(c.build_settings['LIBRARY_SEARCH_PATHS']).flatten.compact.map(&:to_s)
      filtered_paths = search_paths.reject { |path| path.include?(toolchain_swift_path) }.uniq
      c.build_settings['LIBRARY_SEARCH_PATHS'] = filtered_paths unless filtered_paths.empty?

      # Fix for MicrosoftFluentUI Objective-C selector conflicts
      c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      unless c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].include?('FLUENTUI_NAVIGATION_SUBTITLE_FIX=1')
        c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'FLUENTUI_NAVIGATION_SUBTITLE_FIX=1'
      end
    end

    t.shell_script_build_phases.each do |phase|
      next unless warning_phase_names.include?(phase.name)
      phase.always_out_of_date = '1'
    end
  end
  
  # Specific fix for MicrosoftFluentUI subtitle conflict
  fluentui_target = installer.pods_project.targets.find { |target| target.name == 'MicrosoftFluentUI' }
  if fluentui_target
    fluentui_target.build_configurations.each do |config|
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['$(inherited)']
      unless config.build_settings['OTHER_SWIFT_FLAGS'].include?('-DFLUENTUI_DISABLE_SUBTITLE_EXTENSION')
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-DFLUENTUI_DISABLE_SUBTITLE_EXTENSION'
      end
    end
  end

  support_files_pattern = File.join(installer.sandbox.root.to_s, 'Target Support Files', '**', '*.xcconfig')
  Dir.glob(support_files_pattern).each do |xcconfig_path|
    content = File.read(xcconfig_path)
    updated = content.gsub(/ ?"\$\{TOOLCHAIN_DIR\}\/usr\/lib\/swift\/\$\{PLATFORM_NAME\}"/, '')
    File.write(xcconfig_path, updated) if updated != content
  end
end
