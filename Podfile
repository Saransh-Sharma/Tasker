platform :ios, '16.0'

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
  
  # Liquid Glass UI Dependencies
  pod 'SnapKit', '~> 5.6.0'        # Programmatic constraints
  pod 'RxSwift', '~> 6.5.0'        # Reactive programming
  pod 'RxCocoa', '~> 6.5.0'        # UI bindings
  pod 'lottie-ios'        # Liquid animations
  pod 'Hero', '~> 1.6.2'           # Smooth transitions


  target 'TaskerTests' do
    inherit! :search_paths
  end
end          # ← closes the outer 'Tasker' block

# Runs after pods project is generated
post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      # Fix for MicrosoftFluentUI Objective-C selector conflicts
      c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'FLUENTUI_NAVIGATION_SUBTITLE_FIX=1'
    end
  end
  
  # Specific fix for MicrosoftFluentUI subtitle conflict
  fluentui_target = installer.pods_project.targets.find { |target| target.name == 'MicrosoftFluentUI' }
  if fluentui_target
    fluentui_target.build_configurations.each do |config|
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['$(inherited)']
      config.build_settings['OTHER_SWIFT_FLAGS'] << '-DFLUENTUI_DISABLE_SUBTITLE_EXTENSION'
    end
  end
end
