#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'escposprinter'
  s.version          = '0.0.1'
  s.summary          = 'ESC/POS thermal printer plugin for Flutter.'
  s.description      = <<-DESC
A Flutter plugin for USB thermal printing using ESC/POS commands on macOS.
                       DESC
  s.homepage         = 'https://samhaus.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Marcus Felix' => 'marcus@samhaus.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.frameworks = 'IOKit', 'Foundation'
end
