//
//  PHPrecentController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 10/8/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import Foundation

class PHPrecentController{
    
    static func precent(form : UIViewController,isSandBoxEnabled sandBoxEnabled: Bool,withInitRequest request : InitRequest,delegate : PHViewControllerDelegate){
        
        let phVC = PHViewController()
        phVC.initRequest = request
        phVC.delegate = delegate
        phVC.isSandBoxEnabled = false
        phVC.modalPresentationStyle = .overFullScreen
        
        form.present(phVC, animated: true, completion: nil)
        
    }
}
