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

    override func viewDidLoad() {
        super.viewDidLoad()
        
       
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
         let initrequ = InitResonseRequest(JSONString: "{\"merchantId\":\"210251\",\"returnUrl\":\"\",\"cancelUrl\":\"\",\"notifyUrl\":\"\",\"firstName\":\"Saman\",\"lastName\":\"Kumara\",\"email\":\"saman@test.com\",\"phone\":\"0711111111\",\"address\":\"No 20, Galle Road\",\"city\":\"Colombo 01\",\"country\":\"Sri Lanka\",\"orderId\":\"00001\",\"itemsDescription\":\"Helakuru Mug\",\"itemsMap\":null,\"currency\":\"LKR\",\"amount\":100.0,\"deliveryAddress\":\"\",\"deliveryCity\":\"\",\"deliveryCountry\":\"\",\"platform\":\"android\",\"custom1\":\"\",\"custom2\":\"\",\"startupFee\":0.0,\"recurrence\":\"\",\"duration\":\"\",\"referer\":\"lk.bhasha.helakuru\",\"hash\":\"\"}")
                
        PHPrecentController.precentNew(from: self, isSandBoxEnabled: false, withInitRequest: initrequ!, delegate: self)
                

    }
    
    
    @IBAction func btnPressed(_ sender: Any) {
        
        let initrequ = InitResonseRequest(JSONString: "{\"merchantId\":\"210251\",\"returnUrl\":\"\",\"cancelUrl\":\"\",\"notifyUrl\":\"\",\"firstName\":\"Saman\",\"lastName\":\"Kumara\",\"email\":\"saman@test.com\",\"phone\":\"0711111111\",\"address\":\"No 20, Galle Road\",\"city\":\"Colombo 01\",\"country\":\"Sri Lanka\",\"orderId\":\"00001\",\"itemsDescription\":\"Helakuru Mug\",\"itemsMap\":null,\"currency\":\"LKR\",\"amount\":100.0,\"deliveryAddress\":\"\",\"deliveryCity\":\"\",\"deliveryCountry\":\"\",\"platform\":\"android\",\"custom1\":\"\",\"custom2\":\"\",\"startupFee\":0.0,\"recurrence\":\"\",\"duration\":\"\",\"referer\":\"lk.bhasha.helakuru\",\"hash\":\"\"}")
           
        PHPrecentController.precentNew(from: self, isSandBoxEnabled: false, withInitRequest: initrequ!, delegate: self)
        
    }
    

}

extension ViewController : PHViewControllerDelegate{
    
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        print("🤜 Sucess")
    }
    
    
}

