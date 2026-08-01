Pod::Spec.new do |s|
  s.name             = 'PlynxConnector'
  s.version          = '2.6.0'
  s.summary          = 'Swift implementation of the wire protocol used by Plynx apps'
  s.description      = <<-DESC
    PlynxConnector is a Swift library that implements the communication protocol used
    by the Plynx apps: binary TCP over TLS, Bluetooth LE transport, typed commands and
    events, and the data models for projects, devices and widgets. Async/await API with
    automatic reconnection and no third-party dependencies.
  DESC

  s.homepage         = 'https://github.com/NickP005/PlynxConnector'
  s.license          = { :type => 'Proprietary', :file => 'LICENSE' }
  s.author           = { 'NickP005' => '' }
  s.source           = { :git => 'https://github.com/NickP005/PlynxConnector.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.tvos.deployment_target = '15.0'
  s.watchos.deployment_target = '8.0'

  s.swift_versions = ['5.5', '5.6', '5.7', '5.8', '5.9', '5.10']

  s.source_files = 'Sources/**/*.swift'
  
  s.frameworks = 'Foundation', 'Network'
end
