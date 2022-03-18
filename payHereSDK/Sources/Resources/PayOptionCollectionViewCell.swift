//
//  PayOptionCollectionViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 12/18/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import UIKit

final class PayOptionCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imgOptionImage: UIImageView!
    @IBOutlet weak var viewBackground: UIView!
    
    override var isSelected: Bool{
        didSet{
            updateSelection()
        }
    }
    
    override var isHighlighted: Bool{
        didSet{
            updateSelection()
        }
    }
    
    private func updateSelection(){
        UIView.animate(withDuration: PHConfigs.kCellAnimateDuration) {
            if self.isSelected || self.isHighlighted{
                self.viewBackground.backgroundColor = PHConfigs.kHighlightColor
            }
            else{
                self.viewBackground.backgroundColor = PHConfigs.kNormalColor
            }
        }
    }

}
