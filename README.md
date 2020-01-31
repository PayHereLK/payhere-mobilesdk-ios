# PayHere Mobile SDK for iOS
<p>
<a href="https://developer.apple.com/swift"><img src="https://img.shields.io/badge/language-swift5-f48041.svg?style=flat"></a>
<a href="https://developer.apple.com/ios"><img src="https://img.shields.io/badge/platform-iOS%208%2B-blue.svg?style=flat"></a>
<a><img src="https://img.shields.io/badge/CocoaPods-compatible-4BC51D.svg?style=flat"></a>
</p>

PayHere Mobile SDK for iOS allows you to accept payments seamlessly within your iOS app, without redirecting your app user to the web browser.

## Contents
-  [Requirements](#Requirements)
-  [Installation](#Installation)
-  [Usage](#Usage)

## Requirements
- iOS 10.0+
- Xcode 10.2+
- Swift 5.0+

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```
To integrate PayHere into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'payHereSDK'
end
```
Then, run the following command:

```bash
$ pod install
```

## Usage
Import PayHere SDK into your UIViewController 
```swift
import payHereSDK
```
In order to make a payment request, first initialize PayHere ViewController as below;

```swift
PHPrecentController.precent(from: self, isSandBoxEnabled: false, withInitRequest: initRequest!, delegate: self)
```
### Create InitRequest

```swift
 let initRequest = PHInitialRequest(merchantID: merchandID, notifyURL: "", firstName: "Pay", lastName: "Here", email: "test@test.com", phone: "+9477123456", address: "Colombo", city: "Colombo", country: "Sri Lanka", orderID: "001", itemsDescription: "PayHere SDK Sample", itemsMap: [item1,item2], currency: .LKR, amount: 50.00, deliveryAddress: "", deliveryCity: "", deliveryCountry: "", custom1: "custom 01", custom2: "custom 02")
```
### Handle Payment Response

```swifit
extension <<ViewController>> : PHViewControllerDelegate{
    func onResponseReceived(response: PHResponse<Any>?) {
        
        if(response?.isSuccess())!{
            
            guard let resp = response?.getData() as? StatusResponse else{
                return
            }
            
            //Payment Sucess
            
        }else{
            response?.getMessage()
        }
    }
}
```

## FAQ

How to fixed [!] Unable to find a specification for payHereSDK issue 

follow the instruction given bellow

```bash
$ pod repo remove master
$ pod setup
$ pod install
```
