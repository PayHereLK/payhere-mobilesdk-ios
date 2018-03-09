//
//  InitRequest.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

class InitRequest {
    
    var  merchantId : String?
    var  merchantSecret : String?
    
    var customer : Customer?
    
    var orderId : String?
    var itemsDescription  : String?
    var currency : String?
    var amount : Double?
    
    var phInternal : Bool = false
    
    var custom1 : String?
    var custom2 : String?
    
    var items : [Item]?
    
}
