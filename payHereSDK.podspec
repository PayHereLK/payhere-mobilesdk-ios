Pod::Spec.new do |s|

# 1
s.platform = :ios
s.ios.deployment_target = '11.0'
s.name = "payHereSDK"
s.summary = "Mobile SDK for payHere"
s.requires_arc = true

# 2
s.version = "3.0.2"

# 3
s.license = { :type => "MIT", :file => "LICENSE" }

# 4 - Replace with your name and e-mail address
s.author = { "PayHere" => "support@payhere.lk" }

# 5 - Replace this URL with your own Github page's URL (from the address bar)
s.homepage = "https://www.payhere.lk/"

# 6 - Replace this URL with your own Git URL from "Quick Setup"
s.source = { :git => "https://github.com/PayHereLK/payhere-mobilesdk-ios.git", :tag => "#{s.version}"}
# s.resource_bundle = { 'payHereSDK' => 'payHereSDK/Sources/**/*.storyboard' }




# 7
s.frameworks = 'UIKit','WebKit'
s.dependency 'Alamofire', '~> 5.0.0-rc.2'
s.dependency 'AlamofireObjectMapper'
s.dependency 'SDWebImage'



# 8
s.source_files = "payHereSDK/Sources/**/*.{h,m,swift,ttf}"
s.resources = 'payHereSDK/**/*.{lproj,storyboard,xcdatamodeld,xib,xcassets,json,ttf}'
# s.resource_bundles = { 
#    'payHereSDK' => ['payHereSDK/**/*.{lproj,storyboard,xcdatamodeld,xib,xcassets,json,ttf}']
# }

s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }



end
