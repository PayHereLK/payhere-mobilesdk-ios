//
//  Extention.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/6/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

extension Bundle{
    
    internal static var payHereBundle: Bundle{
        return Bundle(for: PHPrecentController.self)
    }
    
}
