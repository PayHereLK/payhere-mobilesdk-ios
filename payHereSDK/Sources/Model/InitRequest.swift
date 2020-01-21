//
//  InitRequest.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

@available(*, deprecated, message: "Use PHInitRequest instead")
public class InitRequest {
    
    public var  merchantId : String?
    public var  merchantSecret : String?
    
    public var customer : Customer?
    
    public var orderId : String?
    public var itemsDescription  : String?
    public var currency : String?
    public var amount : Double?
    
    public var phInternal : Bool = false
    
    public var custom1 : String?
    public var custom2 : String?
    
    public var items : [Item]?
    
    public init(){}
    
}

public class PHInitialRequest{
    
    internal var merchantID, notifyURL: String?
    internal var firstName, lastName, email, phone: String?
    internal var address, city, country, orderID: String?
    internal var itemsDescription: String?
    internal var itemsMap: [Item]?
    internal var currency : PHCurrency?
    internal var amount : Double?
    internal var deliveryAddress, deliveryCity, deliveryCountry: String?
    internal var custom1, custom2 : String?
    
    internal var startupFee: Double?
    internal var recurrence : PHRecurrenceTime?
    internal var duration: PHDuration?
    
    /**
     Use this constructor when you are using [PayHere Checkout API](https://support.payhere.lk/api-&-mobile-sdk/payhere-checkout)
     - Parameter merchantID: Merchant ID Obtain From PayHere.
     - Parameter notifyURL: URL to callback the status of the payment (Needs to be a URL accessible on a public IP/domain)
     - Parameter firstName: First Name of the Customer.
     - Parameter lastName: Last Name of the Customer.
     - Parameter email : Customer’s Email
     - Parameter phone : Customer’s Phone No
     - Parameter address : Customer’s Address Line1 + Line2
     - Parameter city : Customer’s City
     - Parameter country : Customer’s Country
     - Parameter orderID : Order ID generated by the merchant
     - Parameter items : List of `Item`
     - Parameter currency : `PHCurrency` Object
     - Parameter amount : Total Payment Amount
     - Parameter deliveryAddress : Delivery Address Line1 + Line2 (Optional)
     - Parameter deliveryCity : Delivery City (Optinal)
     - Parameter deliveryCountry : Delivery Country (Optional)
     - Parameter custom1 : Custom param 1 set by merchant (Optional)
     - Parameter custom2 : Custom param 2 set by merchant (Optional)
     */
    public init(merchantID: String?, notifyURL: String?, firstName: String?, lastName: String?, email: String?, phone: String?, address: String?, city: String?, country: String?, orderID: String?, itemsDescription: String?, itemsMap: [Item]?, currency: PHCurrency?, amount: Double?, deliveryAddress: String?, deliveryCity: String?, deliveryCountry: String?, custom1: String?, custom2: String?) {
        self.merchantID = merchantID
        self.notifyURL = notifyURL
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.orderID = orderID
        self.itemsDescription = itemsDescription
        self.itemsMap = itemsMap
        self.currency = currency
        self.amount = amount
        self.deliveryAddress = deliveryAddress
        self.deliveryCity = deliveryCity
        self.deliveryCountry = deliveryCountry
        self.custom1 = custom1
        self.custom2 = custom2
    }
    
    /**
    Use this constructor when you are using [PayHere Recurring API](https://support.payhere.lk/api-&-mobile-sdk/payhere-recurring)
    - Parameter merchantID: Merchant ID Obtain From PayHere.
    - Parameter notifyURL: URL to callback the status of the payment (Needs to be a URL accessible on a public IP/domain)
    - Parameter firstName: First Name of the Customer.
    - Parameter lastName: Last Name of the Customer.
    - Parameter email : Customer’s Email
    - Parameter phone : Customer’s Phone No
    - Parameter address : Customer’s Address Line1 + Line2
    - Parameter city : Customer’s City
    - Parameter country : Customer’s Country
    - Parameter order_id : Order ID generated by the merchant
    - Parameter items : List of `Item`
    - Parameter currency : `PHCurrency`
    - Parameter amount : Total Payment Amount
    - Parameter recurrence : `PHRecurrenceTime`
    - Parameter duration : `PHDuration`
    - Parameter deliveryAddress : Delivery Address Line1 + Line2 (Optional)
    - Parameter deliveryCity : Delivery City (Optinal)
    - Parameter deliveryCountry : Delivery Country (Optional)
    - Parameter custom1 : Custom param 1 set by merchant (Optional)
    - Parameter custom2 : Custom param 2 set by merchant (Optional)
   
    */
    
    public  init(merchantID: String?, notifyURL: String?, firstName: String?, lastName: String?, email: String?, phone: String?, address: String?, city: String?, country: String?, orderID: String?, itemsDescription: String?, itemsMap: [Item]?, currency: PHCurrency?, amount: Double?, deliveryAddress: String?, deliveryCity: String?, deliveryCountry: String?, custom1: String?, custom2: String?, startupFee: Double?, recurrence: PHRecurrenceTime?, duration: PHDuration?) {
        self.merchantID = merchantID
        self.notifyURL = notifyURL
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.orderID = orderID
        self.itemsDescription = itemsDescription
        self.itemsMap = itemsMap
        self.currency = currency
        self.amount = amount
        self.deliveryAddress = deliveryAddress
        self.deliveryCity = deliveryCity
        self.deliveryCountry = deliveryCountry
        self.custom1 = custom1
        self.custom2 = custom2
       
        
        self.startupFee = startupFee
        self.recurrence = recurrence
        self.duration = duration
    }
    
}

public enum PHCurrency : String{
    case LKR = "LKR"
    case USD = "GBP"
    case EUR = "EUR"
    case AUD = "AUD"
}

/**
  Recurring Period (A number & a word separated by a space such as 2 Week, 1 Month, 6 Month, 1 Year, etc. Word can be ‘Week’, ‘Month’ or ‘Year’ in singular. Number can be any to define recurrent period with word.)
   ~~~
    PHRecurrenceTime.Week(`number of Weeks`)
    PHRecurrenceTime.Month(`number of Months`)
    PHRecurrenceTime.Year(`number of Year`)
   ~~~
 
 */
public enum PHRecurrenceTime{
    case Week(duration : Int)
    case Month(duration : Int)
    case Year(duration : Int)
}


/**
 Duration to charge ('Forever' if there's no time limitation. Otherwise a Number & a word separated by a space as 1 Month, 1 Year, 3 Year, ect. Word can be ‘Week’, ‘Month’, ‘Year’. Number should be compatible with the word in recurrence.)
  ~~~
    PHDuration.Week(`number of Weeks`)
    PHDuration.Month(`number of Months`)
    PHDuration.Year(`number of Year`)
    PHDuration.Forver
  ~~~
*/
public enum PHDuration{
    case Week(duration : Int)
    case Month(duration : Int)
    case Year(duration : Int)
    case Forver
}



internal  class PHInitRequest : Mappable{
    
    internal  var merchantID, returnURL, cancelURL, notifyURL: String?
    internal  var firstName, lastName, email, phone: String?
    internal  var address, city, country, orderID: String?
    internal  var itemsDescription: String?
    internal  var itemsMap: [String : String]?
    internal  var currency: String?
    internal  var amount: Double?
    internal  var deliveryAddress, deliveryCity, deliveryCountry: String?
    internal  var platform: String?
    internal  var custom1, custom2: String?
    internal  var startupFee: Double?
    internal  var recurrence, duration: String?
    internal  var referer, hash: String?
    internal  var auto : Bool = false
    
    internal init(){
        
    }
    
    internal init(merchantID: String?, returnURL: String?, cancelURL: String?, notifyURL: String?, firstName: String?, lastName: String?, email: String?, phone: String?, address: String?, city: String?, country: String?, orderID: String?, itemsDescription: String?, itemsMap: [String : String]?, currency: String?, amount: Double?, deliveryAddress: String?, deliveryCity: String?, deliveryCountry: String?, platform: String?, custom1: String?, custom2: String?, startupFee: Double?, recurrence: String?, duration: String?, hash: String?) {
        self.merchantID = merchantID
        self.returnURL = returnURL
        self.cancelURL = cancelURL
        self.notifyURL = notifyURL
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.orderID = orderID
        self.itemsDescription = itemsDescription
        self.itemsMap = itemsMap
        self.currency = currency
        self.amount = amount
        self.deliveryAddress = deliveryAddress
        self.deliveryCity = deliveryCity
        self.deliveryCountry = deliveryCountry
        self.platform = platform
        self.custom1 = custom1
        self.custom2 = custom2
        self.startupFee = startupFee
        self.recurrence = recurrence
        self.duration = duration
        self.hash = hash
    }
    
    internal required init?(map: Map) {
        
    }
    
    internal func mapping(map: Map) {
        self.merchantID <- map["merchantId"]
        self.returnURL <- map["returnUrl"]
        self.cancelURL <- map["cancelUrl"]
        self.notifyURL <- map["notifyUrl"]
        self.firstName <- map["firstName"]
        self.lastName <- map["lastName"]
        self.email <- map["email"]
        self.phone <- map["phone"]
        self.address <- map["address"]
        self.city <- map["city"]
        self.country <- map["country"]
        self.orderID <- map["orderId"]
        self.itemsDescription <- map["itemsDescription"]
        self.itemsMap <- map["itemsMap"]
        self.currency <- map["currency"]
        self.amount <- map["amount"]
        self.deliveryAddress <- map["deliveryAddress"]
        self.deliveryCity <- map["deliveryCity"]
        self.deliveryCountry <- map["deliveryCountry"]
        self.platform <- map["platform"]
        self.custom1 <- map["custom1"]
        self.custom2 <- map["custom2"]
        self.startupFee <- map["startupFee"]
        self.recurrence <- map["recurrence"]
        self.duration <- map["duration"]
        self.referer <- map["referer"]
        self.hash <- map["hash"]
        self.auto <- map["auto"]
    }
    
}

extension PHInitRequest {
    
    internal func toRawRequest(url : String) -> URLRequest{
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pjson = self.toJSONString(prettyPrint: false)
        
       
        
        let data = (pjson?.data(using: .utf8))! as Data
        
        request.httpBody = data
        
        
        return request
        
    }
    
}