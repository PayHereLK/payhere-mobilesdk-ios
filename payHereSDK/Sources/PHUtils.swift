//
//  PHUtils.swift
//  payHereSDK
//
//  Created by Thisura Dodangoda on 2022-03-18.
//  Copyright © 2022 PayHere. All rights reserved.
//

import Foundation

func xprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    for (i, v) in items.enumerated(){
        Swift.print(v, separator: "", terminator: "")
        if i < items.count - 1{
            Swift.print(separator, separator: "", terminator: "")
        }
    }
    Swift.print(terminator, separator: "", terminator: "")
    #endif
}
