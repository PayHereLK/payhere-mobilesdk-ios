# PayHere Mobile SDK for iOS
The PayHere iOS SDK makes it easy to add PayHere payments to your mobile apps easily

## Contents
-  [Requirements](#Requirements)
-  [Installation](#Installation)
-  [Usage](#Usage)

## Requirements
- iOS 8.0+
- Xcode 8.3+
- Swift 3.1+

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
import PayHere SDK into your UIViewController as following
```swift
import payHereSDK
```
When you want to make a payment first initialized PayHere ViewController as bellow

```swift
let phVC = PHViewController()
phVC.initRequest = req
phVC.delegate = self
phVC.isSandBoxEnabled = true  
phVC.modalPresentationStyle = .overCurrentContext
        
self.present(phVC, animated: true, completion: nil)
```
### Create InitRequest

```swift
        let req : InitRequest = InitRequest()
        req.merchantId = <Your PayHere MerchantID>
        req.merchantSecret = <Your PayHere Merchant Secret>
        req.amount = 100.0
        req.currency = "LKR"
        req.orderId = "ABCDWXYZ"
        req.itemsDescription = "1 Greeting Card"
        req.custom1 = "This is the custom 1 message"
        req.custom2 = "This is the custom 2 message"
        
        
        let customer = Customer()
        
        customer.firstName = "Nuwan"
        customer.lastName = "Kumara"
        customer.email = "n@gmail.com"
        customer.phone = "+94700000000"
        
        
        let address = Address()
        address.address = "No 43, Galle Road"
        address.city = "Colombo"
        address.country = "Sri Lanka"
        
        
        let deliverAddress = Address()
        deliverAddress.address = "No 100, Galle Road"
        deliverAddress.city = "Kadawatha"
        deliverAddress.country = "Sri Lanka"
        
        
        customer.address = address
        customer.deliveryAddress = deliverAddress
        
        req.customer = customer
        
        req.items = [Item(id: "1", name: "Card", quantity: 1)]
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
