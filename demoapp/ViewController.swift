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
    
    
    let merchandID = "210251"
    
   
    var initRequest : PHInitialRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 120.0)
        let item2 = Item(id: "002", name: "PayHere Test Item 02", quantity: 2, amount: 150.0)
        
        initRequest = PHInitialRequest(merchantID: merchandID, notifyURL: "", firstName: "Pay", lastName: "Here", email: "test@test.com", phone: "+9477123456", address: "Colombo", city: "Colombo", country: "Sri Lanka", orderID: "001", itemsDescription: "PayHere SDK Sample", itemsMap: [item1,item2], currency: .LKR, amount: 270.00, deliveryAddress: "", deliveryCity: "", deliveryCountry: "", custom1: "custom 01", custom2: "custom 02")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    
    @IBAction func btnPressed(_ sender: Any) {
        PHPrecentController.precent(from: self, isSandBoxEnabled: false, withInitRequest: initRequest!, delegate: self)
    }
    

}

extension ViewController : PHViewControllerDelegate{
    
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        print("🤜 Sucess",response!)
    }
    
    
}

