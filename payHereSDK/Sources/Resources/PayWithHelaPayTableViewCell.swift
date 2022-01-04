//
//  PayWithHelaPayTableViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2021-12-29.
//  Copyright © 2021 PayHere. All rights reserved.
//

import UIKit

class PayWithHelaPayTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    public static func dequeue(fromTableView tv: UITableView) -> PayWithHelaPayTableViewCell{
        let cell = tv.dequeueReusableCell(withIdentifier: "PayWithHelaPayTableViewCell") as! PayWithHelaPayTableViewCell
        cell.selectionStyle = .none
        return cell
    }
    
}
