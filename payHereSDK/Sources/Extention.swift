//
//  Extention.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/6/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation
import Alamofire


//extension String {
//
//    var md5: String? {
//        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
//
//        let hash = data.withUnsafeBytes { (bytes: UnsafePointer<Data>) -> [UInt8] in
//            var hash: [UInt8] = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
//            CC_MD5(bytes, CC_LONG(data.count), &hash)
//            return hash
//        }

//       return  MD5(self)

//        return hash.map { String(format: "%02x", $0) }.joined()
//    }


//}

extension Bundle{
    
    internal static var payHereBundle: Bundle{
        return Bundle(for: PHPrecentController.self)
    }
    
}


extension Data {
    func mapToObject<T: Codable>() throws -> T {
        do {
            let decodedData = try JSONDecoder().decode(T.self, from: self)
            return decodedData
        } catch  {
            let failureReason = "Failed to serialize response."
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: Data.newError(failureReason: failureReason)))
        }
    }
    
    internal static func newError(failureReason: String) -> NSError {
        let errorDomain = "com.alamofireobjectmapper.error"
        
        let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
        let returnError = NSError(domain: errorDomain, code: 1, userInfo: userInfo)
        
        return returnError
    }
}
