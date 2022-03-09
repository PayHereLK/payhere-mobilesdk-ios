//
//  InitResponse.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 1/1/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import Foundation

// MARK: - PHInitResponse
struct PHInitResponse: Codable {
    var status: Int?
    var msg: String?
    var data: DataClass?
}

// MARK: - DataClass
struct DataClass: Codable {
    var type: String?
    var order: Order?
    var business: Business?
    var paymentMethods: [PaymentMethod]?
    var redirectType: String?
    var url: String?
}

// MARK: - Business
struct Business: Codable {
    var name: String?
    var logo: String?
    var primaryColor, textColor: String?
}

// MARK: - PaymentMethod
struct PaymentMethod : Codable{
    var method: String?
    var orderNo : Int?
//    var discount: Int?
    var submissionCode : String?
    var submission: Submission?
    var view : UISize?
    
}

struct UISize : Codable{
    var imageUrl : String?
    var windowSize : ViewSize?
}


// MARK: - Order
struct Order: Codable {
    var orderKey: String?
    var amount: Int?
    var amountFormatted, currency, currencyFormatted, shortDescription: String?
    var longDescription: String?
}

// MARK: - Redirection
struct Redirection: Codable {
    var redirectType: String?
    var url: String?
}

// MARK: - Submission
struct Submission : Codable{
    var redirectType: String?
    var url: String?
    var mobileUrls : MobileUrls?
}

struct MobileUrls : Codable{
    var IOS : String?
}

// MARK: - PayHereSubmitResponse
struct PayHereSubmitResponse : Codable{
    var status: Int?
    var msg: String?
    var data: DataClass?
}



// MARK: - Encode/decode helpers

class JSONNull: Codable, Hashable {

    public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
        return true
    }

//    public var hashValue: Int {
//        return 0
//    }
    
    func hash(into hasher: inout Hasher) {
        //MARK: TODO
    }

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

// MARK: - Helper functions for creating encoders and decoders
func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}

