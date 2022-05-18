//
//  PaymentUI.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 1/22/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import Foundation
 // This file was generated from JSON Schema using quicktype, do not modify it directly.
 // To parse the JSON, add this file to your project and do:
 //
 //   let paymentUI = try? newJSONDecoder().decode(PaymentUI.self, from: jsonData)

 // MARK: - PaymentUI
 struct PaymentUI: Codable {
     var status: Int?
     var msg: String?
     var data: [String: Datum]?
     
     func getDataCount() -> Int{
         return data?.keys.count ?? 0
     }
 }

 // MARK: - Datum
 struct Datum: Codable {
     var imageURL: String?
     var viewSize: ViewSize?

     enum CodingKeys: String, CodingKey {
         case imageURL = "imageUrl"
         case viewSize
     }
 }

 // MARK: - ViewSize
 struct ViewSize: Codable {
     var width, height: Int?
 }

