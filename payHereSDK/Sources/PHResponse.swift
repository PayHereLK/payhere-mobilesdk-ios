//
//  PHResponse.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/5/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

public class PHResponse<T> : NSObject{
    
    static var STATUS_SUCCESS : Int { return 1 }
    static var STATUS_ERROR_UNKNOWN : Int { return -1 }
    static var STATUS_ERROR_DATA : Int { return -2 }
    static var STATUS_ERROR_VALIDATION : Int { return -3 }
    static var STATUS_ERROR_NETWORK : Int { return -4 }
    static var STATUS_ERROR_PAYMENT : Int { return -5 }
    
    var status : Int?
    var  message : String?
    var data : T?
    
    
    init(status : Int, message : String) {
        self.status = status
        self.message = message
    }
    
    init(status : Int, message : String, data : T) {
        self.status = status
        self.message = message
        self.data = data
    }
    
    public func getData() -> T?{
        return self.data
    }
    
    public func isSuccess() -> Bool{
        return status == PHResponse.STATUS_SUCCESS
    }
    
    public func getMessage() -> String?{
        return message
    }
    
}

extension PHResponse{
    
    func toString() -> String{
        let firstPart  = String(format:"PHResponse{" + "status=%d, message='%@',data=%s}",status!,message!,data! as! CVarArg)
        return firstPart
    }
}
