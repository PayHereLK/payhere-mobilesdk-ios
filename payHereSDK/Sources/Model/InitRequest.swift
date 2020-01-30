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




