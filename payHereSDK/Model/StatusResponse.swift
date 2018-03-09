//
//  StatusResponse.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/5/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

class StatusResponse : Mappable{
    
    var status : Int?
    var paymentNo : Double?
    var currency : String?
    var price : Double?
    var sign : String?
    var message : String?
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        
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
    }
}

extension StatusResponse{
    func toString()->String?{
        
        let string = self.toJSONString()
        
        return string
    }
}


