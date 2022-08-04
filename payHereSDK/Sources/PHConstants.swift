//
//  PHConstants.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/2/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

public class PHConstants {
    public static let INTENT_EXTRA_DATA = "INTENT_EXTRA_DATA";
    public static let INTENT_EXTRA_RESULT = "INTENT_EXTRA_RESULT";
    
    internal static let PLATFORM : String = "ios"
    internal static let dummyUrl : String = "https://www.payhere.lk/complete/ios";
    internal static let UI : String = "Ui"
    
    /// Payment Completion URL (Live)
    internal static let kLiveCompleteURL = "https://www.payhere.lk/pay/payment/complete"
    
    /// Payment Completion URL (Sandbox)
    internal static let kSandboxCompleteURL = "https://sandbox.payhere.lk/pay/payment/complete"
    
    internal static let kProgressBarWhitelistKeywordFrimi = "frimi"
    internal static let kProgressBarWhitelistKeywordFrimiResponse = "frimi/1/response"
    
}
