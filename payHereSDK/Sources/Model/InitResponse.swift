//
//  InitResponse.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 1/1/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import Foundation

// MARK: - InitResponse
struct InitResponse: Codable {
    let status: Int
    let msg: String?
    let data: DataClass
}

// MARK: - DataClass
struct DataClass: Codable {
    let order: Order
    let business: Business
    let paymentMethods: [String]
}

// MARK: - Business
struct Business: Codable {
    let name: String
    let logo: String
}

// MARK: - Order
struct Order: Codable {
    let orderKey: String
    let amount: Int
    let amountFormatted, currency, currencyFormatted, shortDescription: String
    let longDescription: String?
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

