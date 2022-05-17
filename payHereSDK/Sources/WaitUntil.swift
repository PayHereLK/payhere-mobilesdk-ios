//
//  WaitUntil.swift
//  payHereSDK
//
//  Created by Thisura Dodangoda on 2022-05-17.
//  Copyright © 2022 PayHere. All rights reserved.
//

import Foundation

/**
 Wait until a condition is true to execute a handler
 */
internal class WaitUntil{
    
    private let condition: (() -> Bool)!
    private let completion: (() -> Void)!
    private let timeout: TimeInterval!
    
    init(
        condition: @escaping () -> Bool,
        onCompletion: @escaping () -> Void,
        timeout: TimeInterval = 5.0
    ){
        self.condition = condition
        self.completion = onCompletion
        self.timeout = timeout
        
        run()
    }
    
    private func run(){
        guard !condition() else {
            completion()
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }
            
            let start = Date().timeIntervalSince1970
            var shouldBreak = false
            var isTimeout = false
            
            while(!shouldBreak){
                usleep(80000)
                
                DispatchQueue.main.async {
                    if self.condition(){
                        shouldBreak = true
                    }
                }
                
                if ((Date().timeIntervalSince1970 - start) > self.timeout){
                    shouldBreak = true
                    isTimeout = true
                }
            }
            
            guard !isTimeout else { return }
            
            DispatchQueue.main.async {
                self.completion()
            }
        }
    }
    
}
