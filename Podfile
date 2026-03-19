platform :ios, '16.0'

target 'SkeenaSystem' do
  use_frameworks!

  pod 'MediaPipeTasksVision', '~> 0.10.14'

  target 'SkeenaSystemTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  # Fix the test target xcconfig: remove MediaPipe force_load (already in host app)
  # and add -lz which MediaPipe needs transitively.
  test_config_dir = "#{installer.sandbox.root}/Target Support Files/Pods-SkeenaSystemTests"
  Dir.glob("#{test_config_dir}/*.xcconfig").each do |xcconfig_path|
    content = File.read(xcconfig_path)
    # Remove force_load lines for MediaPipe
    content.gsub!(/OTHER_LDFLAGS\[sdk=.*\].*force_load.*MediaPipe.*\n/, '')
    # Add -lz to base OTHER_LDFLAGS if not already present
    if content.include?('OTHER_LDFLAGS') && !content.include?('-lz')
      content.gsub!(/^(OTHER_LDFLAGS = .*)$/, '\1 -lz')
    end
    File.write(xcconfig_path, content)
  end
end
