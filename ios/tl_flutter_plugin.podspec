#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint plugin_tealeaf.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tl_flutter_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.*h'
  s.swift_version = '4.0'
  s.dependency 'Flutter'
  s.dependency 'TealeafDebug'
  # s.dependency 'Realm'
  s.platform = :ios, '12.0'

#  s.subspec 'Acoustic' do |ac|
#    ac.source = 'https://github.com/CocoaPods/Specs.git'
#    ac.public_header_files = 'Headers/Public/*.h'
#    ac.dependency 'Tealeaf'
#    ac.dependency 'Realm'
#  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
