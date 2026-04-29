Pod::Spec.new do |spec|
  spec.name         = "LookinServer"
  spec.version      = "0.1.0"
  spec.summary      = "The iOS runtime server used by Viewglass."
  spec.description  = "Embed this framework into your debug iOS project to enable Viewglass runtime inspection and actions."
  spec.homepage     = "https://github.com/WZBbiao/ViewglassServer"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "WZBbiao" => "544856638@qq.com" }
  spec.ios.deployment_target  = "9.0"
  spec.tvos.deployment_target  = '9.0'
  spec.visionos.deployment_target = "1.0"
  spec.default_subspecs = 'Core'
  spec.source       = { :git => "https://github.com/WZBbiao/ViewglassServer.git", :tag => "0.1.0"}
  spec.frameworks = "UIKit", "AVFoundation", "CoreImage", "CoreMedia", "CoreVideo"
  spec.requires_arc = true
    
  spec.subspec 'Core' do |ss|
    ss.source_files = ['Src/Main/**/*', 'Src/Base/**/*']
    ss.pod_target_xcconfig = {
       'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SHOULD_COMPILE_LOOKIN_SERVER=1',
       'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) SHOULD_COMPILE_LOOKIN_SERVER'
    }
  end

  spec.subspec 'Swift' do |ss|
    ss.dependency 'LookinServer/Core'
    ss.source_files = 'Src/Swift/**/*'
    ss.pod_target_xcconfig = {
       'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) LOOKIN_SERVER_SWIFT_ENABLED=1',
       'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LOOKIN_SERVER_SWIFT_ENABLED'
    }
  end

  spec.subspec 'NoHook' do |ss|
    ss.dependency 'LookinServer/Core'
    ss.pod_target_xcconfig = {
       'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) LOOKIN_SERVER_DISABLE_HOOK=1',
    }
  end
  
  # CocoaPods 不支持多个 subspecs 和 configurations 并列
  # "pod 'LookinServer', :subspecs => ['Swift', 'NoHook'], :configurations => ['Debug']" is not supported by CocoaPods
  # https://github.com/QMUI/LookinServer/issues/134
  spec.subspec 'SwiftAndNoHook' do |ss|
    ss.dependency 'LookinServer/Core'
    ss.source_files = 'Src/Swift/**/*'
    ss.pod_target_xcconfig = {
       'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) LOOKIN_SERVER_SWIFT_ENABLED=1 LOOKIN_SERVER_DISABLE_HOOK=1',
       'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) LOOKIN_SERVER_SWIFT_ENABLED'
    }
  end

end
