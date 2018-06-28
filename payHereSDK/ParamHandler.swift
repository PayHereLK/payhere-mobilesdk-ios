//
//  ParamHandler.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/5/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import UIKit

public class ParamHandler{
    
    public static func createParams(req : InitRequest)->[String : String?]{
        
        let map : [String : String?] = [
            "merchant_id"   : req.merchantId!,
            "return_url"    : PHConstants.dummyUrl,
            "cancel_url"    : PHConstants.dummyUrl,
            "notify_url"    : PHConstants.dummyUrl,
            "first_name"    : (req.customer?.firstName),
            "last_name"     : (req.customer?.lastName),
            "email"         : (req.customer?.email),
            "phone"         : (req.customer?.phone),
            "address"       : (req.customer?.address?.address),
            "city"          : (req.customer?.address?.city),
            "country"       : (req.customer?.address?.country),
            "order_id"      : (req.orderId),
            "items"         : (req.itemsDescription),
            "currency"      : (req.currency),
            "amount"        : String(format: "%0.2f",req.amount!),
            "delivery_address" : (req.customer?.deliveryAddress?.address),
            "delivery_city" : (req.customer?.deliveryAddress?.city)!,
            "delivery_country" : (req.customer?.deliveryAddress?.country),
            "internal_checkout" : "false",
            "platform"      : PHConstants.PLATFORM,
            "custom_1"      : req.custom1,
            "custom_2"      : req.custom2,
            "referer"       : Bundle.main.bundleIdentifier
        ]
        
        
        return map
    }
    
}
