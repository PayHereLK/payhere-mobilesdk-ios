# PayHere Mobile SDK for iOS
[![Language](https://img.shields.io/badge/Language-swift-orange?style=flat-square)](https://developer.apple.com/swift) [![Platforms](https://img.shields.io/cocoapods/p/payHereSDK?style=flat-square)](https://developer.apple.com/ios) [![CocoaPods](https://img.shields.io/cocoapods/v/payHereSDK.svg?style=flat)](https://cocoapods.org/pods/payHereSDK) [![License](https://img.shields.io/cocoapods/l/payHereSDK.svg?style=flat-square)](https://cocoapods.org/pods/payHereSDK) ![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-green?style=flat-square) [![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

PayHere Mobile SDK for iOS allows you to accept payments seamlessly within your iOS app, without redirecting your app user to the web browser.

## Contents
-  [Requirements](#Requirements)
-  [Installation](#Installation)
-  [Usage](#Usage)

## Requirements
- iOS 13.0+
- Xcode 15.0+
- Swift 5.0+

## Installation

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. It's integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

To integrate PayHere into your Xcode project using Swift Package Manager:

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package repository URL:
   ```
   https://github.com/PayHereLK/payhere-mobilesdk-ios.git
   ```
3. Select the version you want to use
4. Click **Add Package**

Alternatively, you can add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/PayHereLK/payhere-mobilesdk-ios.git", from: "3.2.2")
]
```

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```
To integrate PayHere into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '13.0'
use_frameworks! # add this line if not present

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
### Create InitRequest

#### CheckOut
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "Pay", 
    lastName: "Here", 
    email: "test@test.com", 
    phone: "+9477123456", 
    address: "Colombo", 
    city: "Colombo", 
    country: "Sri Lanka", 
    orderID: "001", 
    itemsDescription: "PayHere SDK Sample", 
    itemsMap: [item], 
    currency: .LKR, 
    amount: 50.00,
    deliveryAddress: "", 
    deliveryCity: "", 
    deliveryCountry: "", 
    custom1: "custom 01", 
    custom2: "custom 02"
)
```
#### PreApproval
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "001", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    custom1: "", 
    custom2: ""
)
```

#### Recurring
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "002", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    amount: 60.50, 
    deliveryAddress: "", 
    deliveryCity: "", 
    deliveryCountry: "", 
    custom1: "", 
    custom2: "", 
    startupFee: 0.0, 
    recurrence: .Month(duration: 2), 
    duration: .Forver
)
```
#### PreApproval
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
    merchantID: merchantID, 
    notifyURL: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    phone: "", 
    address: "", 
    city: "", 
    country: "", 
    orderID: "001", 
    itemsDescription: "", 
    itemsMap: [item1], 
    currency: .LKR, 
    custom1: "", 
    custom2: ""
)
```

#### Hold On Card
```swift
let merchantID = ""
let item = Item(id: "item_1", name: "Item 1", quantity: 1, amount: 50.0)
let initRequest = PHInitialRequest(
            merchantID: merchandID,
            notifyURL: "",
            firstName: "",
            lastName: "",
            email: "",
            phone: "",
            address: "",
            city: "",
            country: "",
            orderID: "",
            itemsDescription: "",
            itemsMap: [item1,item2],
            currency: .LKR,
            amount: 0.0,
            deliveryAddress: "",
            deliveryCity: "",
            deliveryCountry: "",
            custom1: "",
            custom2: "",
            isHoldOnCardEnabled: true 
)
```

### Precent PayHere Payment View
In order to make a payment request, first initialize PayHere ViewController as below;

```swift
PHPrecentController.precent(from: self, withInitRequest: initRequest, delegate: self)
```

### Handle Payment Response

```swift
extension ViewController : PHViewControllerDelegate{
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        guard let response = response else {
            print("Could not receive payment response")
            return
        }
        if(response.isSuccess()){
            
            guard let resp = response.getData() as? payHereSDK.StatusResponse else{
                return
            }
            
            print("Payment Success")
            print("Payment Status", resp.status ?? -1)
            print("Message", resp.message ?? "Unknown Message")
            print("Payment No", resp.paymentNo ?? -1.0)
            print("Payment Amount", resp.price ?? -1.0)
            
        }
        else{
            print("Payment Error", response.getMessage() ?? "Unknown Message")
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
