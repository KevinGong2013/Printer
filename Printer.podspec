#
#  Be sure to run `pod spec lint Printer.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "Printer"
  s.version      = "4.1.0"
  s.summary      = "Swift ticket printer framework for ESC/POS-compatible thermal printers."

  s.homepage     = "https://github.com/KevinGong2013/Printer"
  
  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.author             = { "kevin" => "aoxianglele@icloud.com" }
 
  s.platform     = :ios, "9.0"
  s.ios.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/KevinGong2013/Printer.git", :tag => s.version.to_s }

  s.framework  = "CoreBluetooth"
  s.swift_version = '5.0'

  s.source_files = "Sources/Printer/**/*.{swift, h}"
  
end
