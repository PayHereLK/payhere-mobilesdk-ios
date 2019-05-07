//
//  PHConfigs.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

class PHConfigs {
    
    public static let LIVE_URL : String = "https://www.payhere.lk/pay/"
    public static let SANDBOX_URL : String = "https://sandbox.payhere.lk/pay/"
    
    public static let CHECKOUT : String =  "checkout";
    public static let STATUS : String =  "order_status";
    
    public static var BASE_URL : String? = nil
    
    static func setBaseUrl(url : String){
        BASE_URL = url
    }
    
    
}
