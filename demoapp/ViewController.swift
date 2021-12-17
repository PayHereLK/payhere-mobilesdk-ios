//
//  ViewController.swift
//  demoapp
//
//  Created by Kamal Upasena on 1/9/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import UIKit
import payHereSDK

class ViewController: UIViewController {
    
    
    
    let merchandID = "1211149" //"210251"
   
    var initRequest : PHInitialRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    @IBAction func btnCheckOutPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 25.00)
        let item2 = Item(id: "002", name: "PayHere Test Item 02", quantity: 2, amount: 25.0)
        
        //MARK: CheckOut API
        initRequest = PHInitialRequest(merchantID: merchandID,
                                       notifyURL: "",
                                       firstName: "Pay",
                                       lastName: "Here",
                                       email: "test@test.com",
                                       phone: "+9477123456",
                                       address: "Colombo",
                                       city: "Colombo",
                                       country: "Sri Lanka",
                                       orderID: "001",
                                       itemsDescription: "PayHere SDK Sample",
                                       itemsMap: [item1,item2],
                                       currency: .LKR,
                                       amount: 50.00,
                                       deliveryAddress: "",
                                       deliveryCity: "",
                                       deliveryCountry: "",
                                       custom1: "custom 01",
                                       custom2: "custom 02")
        
        
        PHPrecentController.precent(from: self, withInitRequest: initRequest!, delegate: self)
    }
    
    
    @IBAction func btnPreApprovalPressed(_ sender: Any) {
        
         let item1 = Item(id: "001",
                          name: "PayHere Test Item 01",
                          quantity: 1,
                          amount: 60.00)
        
        //MARK: Pre Approval API
        initRequest = PHInitialRequest(merchantID: merchandID,
                                       notifyURL: "",
                                       firstName: "",
                                       lastName: "",
                                       email: "",
                                       phone: "",
                                       address: "",
                                       city: "",
                                       country: "",
                                       orderID: "001",
                                       itemsDescription: "",
                                       itemsMap: [item1],
                                       currency: .LKR,
                                       custom1: "",
                                       custom2: "")
        
        
        
        PHPrecentController.precent(from: self, withInitRequest: initRequest!, delegate: self)
    }
    
    @IBAction func btnRecurringPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 60.00)
        
        
        //MARK: Recurring API
        initRequest = PHInitialRequest(merchantID: merchandID, notifyURL: "", firstName: "", lastName: "", email: "", phone: "", address: "", city: "", country: "", orderID: "002", itemsDescription: "", itemsMap: [item1], currency: .LKR, amount: 60.50, deliveryAddress: "", deliveryCity: "", deliveryCountry: "", custom1: "", custom2: "", startupFee: 0.0, recurrence: .Month(period: 2), duration: .Forver)
        
        PHPrecentController.precent(from: self, withInitRequest: initRequest!, delegate: self)
        
    }
    
    @IBAction func btnHoldOnCardPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 25.00)
        let item2 = Item(id: "002", name: "PayHere Test Item 02", quantity: 2, amount: 25.0)
        
        //MARK: CheckOut API
        initRequest = PHInitialRequest(
            merchantID: merchandID,
            notifyURL: "",
            firstName: "Pay",
            lastName: "Here",
            email: "test@test.com",
            phone: "+9477123456",
            address: "Colombo",
            city: "Colombo",
            country: "Sri Lanka",
            orderID: "001",
            itemsDescription: "PayHere SDK Sample",
            itemsMap: [item1,item2],
            currency: .LKR,
            amount: 50.00,
            deliveryAddress: "",
            deliveryCity: "",
            deliveryCountry: "",
            custom1: "custom 01",
            custom2: "custom 02",
            isHoldOnCardEnabled: true
        )
        
      
        
        
        PHPrecentController.precent(from: self, withInitRequest: initRequest!, delegate: self)
    }
}

extension ViewController : PHViewControllerDelegate{
    
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        if(response?.isSuccess())!{
            
            guard let resp = response?.getData() as? StatusResponse else{
        
                return
            }
            print(resp.message ?? "" as Any)
            //Payment Sucess
            
        }else{
            print(response?.getMessage() ?? "")
            
        }
    }
    
    
}

