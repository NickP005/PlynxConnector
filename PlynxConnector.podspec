Pod::Spec.new do |s|
  s.name             = 'PlynxConnector'
  s.version          = '1.0.0'
  s.summary          = 'Swift iOS connector for Plynx/Blynk IoT server'
  s.description      = <<-DESC
    PlynxConnector is a Swift library that provides a complete interface to control 
    IoT devices through a Plynx (Blynk Legacy) server using the binary TCP/SSL protocol.
    Features include async/await support, automatic reconnection, and full protocol coverage.
  DESC

  s.homepage         = 'https://github.com/NickP005/PlynxConnector'
  s.license          = { :type => 'Proprietary', :file => 'swift/LICENSE' }
  s.author           = { 'NickP005' => '' }
  s.source           = { :git => 'https://github.com/NickP005/PlynxConnector.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.tvos.deployment_target = '15.0'
  s.watchos.deployment_target = '8.0'

  s.swift_versions = ['5.5', '5.6', '5.7', '5.8', '5.9', '5.10']

  s.source_files = 'swift/Sources/**/*.swift'
  
  s.frameworks = 'Foundation', 'Network'
end
