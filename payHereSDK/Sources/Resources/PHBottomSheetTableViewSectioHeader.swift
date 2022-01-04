//
//  PHBottomSheetTableViewSectioHeader.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2021-12-29.
//  Copyright © 2021 PayHere. All rights reserved.
//

import UIKit

class PHBottomSheetTableViewSectioHeader: UITableViewHeaderFooterView {
    
    @IBOutlet weak var lblPaymentMethod: UILabel!
    

    public static func dequeue(fromTableView tv: UITableView) -> PHBottomSheetTableViewSectioHeader{
        
       
        
        let header = tv.dequeueReusableHeaderFooterView(withIdentifier: "PHBottomSheetTableViewSectioHeader") as! PHBottomSheetTableViewSectioHeader
       
        
        return header
    }

}
