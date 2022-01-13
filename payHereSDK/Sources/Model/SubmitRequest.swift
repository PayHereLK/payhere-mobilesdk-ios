//
//  SubmitRequest.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2022-01-05.
//  Copyright © 2022 PayHere. All rights reserved.
//

import Foundation
import ObjectMapper
import UIKit

internal class SubmitRequest : Mappable{
    
    var key : String?
    var method : String?
    
    required init?(map: Map) {
        
    }
    
    init(){
        
    }
    
    func mapping(map: Map) {
        key <- map["key"]
        method <- map["method"]
    }
    
    
}

extension SubmitRequest {
    
    internal func toRawRequest(url : String) -> URLRequest{
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pjson = self.toJSONString(prettyPrint: false)
        let data = (pjson?.data(using: .utf8))! as Data
        
        request.httpBody = data
        
        
        return request
        
    }
    
}

