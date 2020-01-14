//
//  Item.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper

public class Item : Mappable{
    
    public var id: String?
    public var name : String?
    public var quantity : Int?
    public var amount : Double?
    
    public init() {}
    
    public init(id: String?, name: String?, quantity: Int?, amount: Double?) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.amount = amount
    }
    
    public required init?(map: Map) {
        
    }
    
    public func mapping(map: Map) {
        self.id <- map["id"]
        self.name <- map["name"]
        self.quantity <- map["quantity"]
        self.amount <- map["amount"]
    }
    
    
}
