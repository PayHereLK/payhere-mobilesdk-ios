//
//  InitRequest.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

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

public class InitResonseRequest : Mappable{
    
    public var merchantID, returnURL, cancelURL, notifyURL: String?
    public var firstName, lastName, email, phone: String?
    public var address, city, country, orderID: String?
    public var itemsDescription: String?
    public var itemsMap: [Item]?
    public var currency: String?
    public var amount: Double?
    public var deliveryAddress, deliveryCity, deliveryCountry: String?
    public var platform: String?
    public var custom1, custom2: String?
    public var startupFee: Double?
    public var recurrence, duration: String?
    public var referer, hash: String?
    
    
    
    public required init?(map: Map) {
        
    }
    
    public func mapping(map: Map) {
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
    }
    
}

extension InitResonseRequest {
    
    func toRawRequest(url : String) -> URLRequest{
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pjson = self.toJSONString(prettyPrint: false)
        
        let data = (pjson?.data(using: .utf8))! as Data
        
        request.httpBody = data
        
        
        return request
        
    }
    
}
