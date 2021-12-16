//
//  StatusResponse.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/5/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

public class StatusResponse : Mappable{
    
    public var status : Int?
    public var paymentNo : Double?
    public var currency : String?
    public var price : Double?
    public var sign : String?
    public var message : String?
    
    public required init?(map: Map) {
        
    }
    
    public func mapping(map: Map) {
        
        if(map.mappingType == .toJSON){
            
            status <- map["status"]
            paymentNo <- map["paymentNo"]
            message <- map["message"]
            
        }else{
            
            status <- map["status"]
            paymentNo <- map["paymentNo"]
            currency <- map["currency"]
            price <- map["price"]
            sign <- map["sign"]
            message <- map["message"]
            
        }
    }
    
    public func getStatusState() -> Status?{
        return Status(rawValue: status!)
    }
    
    public enum Status : Int{
        case INIT = 0
        case PAYMENT = 1
        case SUCCESS = 2
        case FAILED = -2
        case AUTHORIZED = 3
    }
}

extension StatusResponse{
    func toString()->String?{
        
        let string = self.toJSONString()
        
        return string
    }
}


