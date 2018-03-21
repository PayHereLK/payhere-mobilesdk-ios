//
//  Item.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

public class Item {
    
    private var id: String?
    private var name : String?
    private var quantity : Int?
    
    init() {}
    
    init(id : String, name : String, quantity : Int) {
        self.id = id
        self.name = name
        self.quantity = quantity
    }
}
