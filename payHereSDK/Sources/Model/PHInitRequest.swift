//
//  PHInitRequest.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 1/23/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

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
    internal  var method : String?
    internal  var auto : Bool = false
    internal  var authorize : Bool = false
    
    
    internal init(){
        
    }
    
    internal init(merchantID: String?, returnURL: String?, cancelURL: String?, notifyURL: String?, firstName: String?, lastName: String?, email: String?, phone: String?, address: String?, city: String?, country: String?, orderID: String?, itemsDescription: String?, itemsMap: [String : String]?, currency: String?, amount: Double?, deliveryAddress: String?, deliveryCity: String?, deliveryCountry: String?, platform: String?, custom1: String?, custom2: String?, startupFee: Double?, recurrence: String?, duration: String?, hash: String?,method : String?) {
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
        self.method = method
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
        self.method <- map["method"]
        self.authorize <- map["authorize"]
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
