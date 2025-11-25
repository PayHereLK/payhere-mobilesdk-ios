Pod::Spec.new do |s|

    #
    # GENERAL
    #
    
    s.platform = :ios
    s.ios.deployment_target = '13.0'
    s.name = "payHereSDK"
    s.summary = "Mobile SDK for payHere"
    s.requires_arc = true
    
    #
    # VERSION
    #
    
    s.version = "3.2.0"
    
    #
    # LICENSE
    #
    
    s.license = { :type => "MIT", :file => "LICENSE" }
    
    #
    # AUTHOR
    #
    
    s.author = { "PayHere" => "support@payhere.lk" }
    
    #
    # HOMEPAGE
    #
    
    s.homepage = "https://www.payhere.lk/"
    
    #
    # SOURCE
    #
    
    s.source = { :git => "https://github.com/PayHereLK/payhere-mobilesdk-ios.git", :tag => "#{s.version}"}
    
    #
    # DEPENDANCIES
    #
    
    s.frameworks = 'UIKit','WebKit'
    s.dependency 'Alamofire', '~> 5.10.2'
    s.dependency 'ObjectMapper'
    s.dependency 'SDWebImage'
    
    #
    # SOURCE FILES
    #
    
    s.source_files = "payHereSDK/Sources/**/*.{h,m,swift,ttf}"
    s.resources = 'payHereSDK/**/*.{lproj,storyboard,xcdatamodeld,xib,xcassets,json,ttf}'
    
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
    
end
