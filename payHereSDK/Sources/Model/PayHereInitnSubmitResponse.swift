//
//  PayHereInitnSubmitResponse.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2022-01-18.
//  Copyright © 2022 PayHere. All rights reserved.
//

import Foundation

struct PayHereInitnSubmitResponse : Codable{
    var status: Int?
    var msg: String?
    var data: InitAndSubmitData?
}

// MARK: - DataClass
struct InitAndSubmitData : Codable{
    var order: Order?
    var business: Business?
    var paymentMethods: [String]?
    var redirection: Redirection?
}


