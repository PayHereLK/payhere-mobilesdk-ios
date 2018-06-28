Pod::Spec.new do |s|

# 1
s.platform = :ios
s.ios.deployment_target = '9.0'
s.name = "payHereSDK"
s.summary = "Mobile SDK for payHere"
s.requires_arc = true

# 2
s.version = "0.1.5"

# 3
s.license = { :type => "MIT", :file => "LICENSE" }

# 4 - Replace with your name and e-mail address
s.author = { "PayHere" => "support@payhere.lk" }

# 5 - Replace this URL with your own Github page's URL (from the address bar)
s.homepage = "https://www.payhere.lk/"

# 6 - Replace this URL with your own Git URL from "Quick Setup"
s.source = { :git => "https://github.com/PayHereLK/payhere-mobilesdk-ios.git", :tag => "#{s.version}"}


# 7
s.framework = "UIKit"
s.dependency 'Alamofire'
s.dependency 'AlamofireObjectMapper'
s.dependency 'SwiftHash'


# 8
s.source_files = "payHereSDK/**/*"
s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.0' }



end
