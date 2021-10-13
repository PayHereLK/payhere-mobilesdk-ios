//
//  PHPrecentController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 10/8/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import Foundation

public class PHPrecentController{
    
//    @available(*, deprecated, message: "Use method signature with InitResonseRequest")
//    public static func precent(form : UIViewController,isSandBoxEnabled sandBoxEnabled: Bool,withInitRequest request : InitRequest,delegate : PHViewControllerDelegate){
//        
//        let phVC = PHViewController()
//        phVC.initRequest = request
//        phVC.delegate = delegate
//        phVC.isSandBoxEnabled = false
//        phVC.modalPresentationStyle = .overFullScreen
//        
//        form.present(phVC, animated: true, completion: nil)
//        
//    }
    
    public static func precent(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        
        let bundle = Bundle.payHereBundle
        let storyBoard: UIStoryboard = UIStoryboard(name: "PayHere", bundle: bundle)
        if let initialController = storyBoard.instantiateViewController(withIdentifier: "PHBottomViewController") as? PHBottomViewController{
            
            var isSandBoxEnabled : Bool  = false
            
            if (request.merchantID?.starts(with: "1"))!{
                isSandBoxEnabled = true
            }else{
                isSandBoxEnabled = false
            }
            
            
            print(isSandBoxEnabled)
            
            initialController.initialRequest = request
            initialController.isSandBoxEnabled = isSandBoxEnabled
            initialController.shouldShowSucessView = showPaymentStatus
            initialController.delegate = delegate
        
            from.modalPresentationStyle = .overCurrentContext
            from.modalTransitionStyle = .crossDissolve
            initialController.modalPresentationStyle = .overCurrentContext
            initialController.modalTransitionStyle = .crossDissolve
            
            from.present(initialController, animated: true, completion: nil)
                
            
        }
    }
}
