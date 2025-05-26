platform :ios, '15.0'

target 'Tasker' do
  use_frameworks!
  use_modular_headers!

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
  pod 'MicrosoftFluentUI',       '~> 0.1.0'

  target 'TaskerTests' do
    inherit! :search_paths
  end
end          # ← closes the outer 'Tasker' block

# Runs after pods project is generated
post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
