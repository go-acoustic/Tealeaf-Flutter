require 'json'

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint tl_flutter_plugin.podspec` to validate before publishing.
#

# Load and parse package and Tealeaf configuration
# package = JSON.parse(File.read('package.json'))
# Load and parse pubspec.yaml configuration
pubspec = YAML.load_file('../pubspec.yaml')
teaLeafConfig = JSON.parse(File.read('../automation/TealeafConfig.json'))

# Extract values from configurations
repository = pubspec["repository"]
useRelease = teaLeafConfig["Tealeaf"]["useRelease"]
dependencyName = useRelease ? 'Tealeaf' : 'TealeafDebug'
iOSVersion = teaLeafConfig["Tealeaf"]["iOSVersion"]
dependencyVersion = iOSVersion.to_s.empty? ? "" : "#{iOSVersion}"
tlDependency = "'#{dependencyName}'#{dependencyVersion}"

puts "*********flutter-native-acoustic-ea-tealeaf-beta.podspec*********"
puts "teaLeafConfig:"
puts JSON.pretty_generate(teaLeafConfig)
puts "repository:#{repository}"
puts "useRelease:#{useRelease}"
puts "dependencyName:#{dependencyName}"
puts "dependencyVersion:#{dependencyVersion}"
puts "tlDependency:#{dependencyName}#{dependencyVersion}"
puts "'#{dependencyName}'#{dependencyVersion}"
puts "***************************************************************"

# Podspec definition starts here
Pod::Spec.new do |s|
  s.name             = 'tl_flutter_plugin' # Updated name to target
  s.version          = pubspec["version"] # Version from pubspec.yaml
  s.summary          = 'Tealeaf flutter plugin project.' # Keeping target summary
  s.description      = <<-DESC
A new flutter plugin project uses native SDKs and Flutter code to capture user experience.
                       DESC
  s.homepage         = pubspec["homepage"] # Homepage from pubspec.yaml
  s.license          = { :file => '../LICENSE' } # License file location
  s.author           = { 'Your Company' => 'email@example.com' }
  s.platform         = :ios, '12.0' # iOS platform version
  
  # Source configuration with dynamic version tag
  # s.source           = { :git => repository, :tag => s.version }
  s.source           = { :path => '.' }

  # Define source files and preserve paths
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.*h'
  
  # Dependencies
  s.dependency 'Flutter' # Flutter dependency
  s.dependency dependencyName, dependencyVersion # Tealeaf dependency.  Commma is required here
  # Optional: Add any additional dependencies here
  
  # Target xcconfig for Flutter
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '../../../ios/Pods/** ' # Search paths
  }
  
  # Custom script phase for build config.  Don't think we need it, use launch.json prelaunch task instead
  # s.script_phase = {
  #   name: 'Build Config',
  #   script: %(
  #     "${PODS_TARGET_SRCROOT}/ios/TealeafConfig/Build_Config.rb" "$PODS_ROOT" "TealeafConfig.json"
  #   ), 
  #   execution_position: :before_compile,
  # }
end
