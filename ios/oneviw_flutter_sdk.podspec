#
# OneViw Flutter SDK — native config bridge for iOS.
#
Pod::Spec.new do |s|
  s.name             = 'oneviw_flutter_sdk'
  s.version          = '1.0.0'
  s.summary          = 'OneViw analytics & product-insights SDK for Flutter.'
  s.description      = <<-DESC
Reads OneViw configuration from Info.plist (oneviw.PROJECT_TOKEN / oneviw.HOST)
and bridges it to the OneViw Flutter SDK.
                       DESC
  s.homepage         = 'https://oneviw.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'OneViw' => 'support@oneviw.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
