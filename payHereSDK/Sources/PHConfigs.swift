//
//  PHConfigs.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

class PHConfigs {
    
    internal static let LIVE_URL : String = "https://www.payhere.lk/pay/"
    internal static let SANDBOX_URL : String = "https://sandbox.payhere.lk/pay/"
    
    
    internal static let CHECKOUT : String =  "checkout";
    internal static let STATUS : String =  "order_status";
    internal static let INITNSUBMIT : String =  "api/payment/initAndSubmit"
    internal static let INIT : String = "api/payment/v2/init"
    internal static let SUBMIT : String = "api/payment/submit"
    public static let UI : String = "api/data/paymentMethods"
    
    internal static let kFontSize = 16.0
    
    internal static let kNormalColor = UIColor(
        displayP3Red: 239/255,
        green: 241/255,
        blue: 244/255,
        alpha: 1.0)
    
    internal static let kHighlightColor = UIColor(
        displayP3Red: 208/255,
        green: 211/255,
        blue: 215/255,
        alpha: 1.0)
    
    internal static let kBlue = UIColor(
        displayP3Red: 0,
        green: 121/255,
        blue: 254/255,
        alpha: 1.0)
    
    internal static let kRed = UIColor(
        displayP3Red: 1,
        green: 64/255,
        blue: 67/255,
        alpha: 1.0)
    
    internal static let kCellAnimateDuration: TimeInterval = 0.08
    
    
    public static var BASE_URL : String? = nil
    
    static func setBaseUrl(url : String){
        BASE_URL = url
    }
    
    
}
