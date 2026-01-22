//
//  PayOptionCollectionViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 12/18/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import UIKit

final public class PayOptionCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imgOptionImage: UIImageView!
    @IBOutlet weak var viewBackground: UIView!
    
    public override var isSelected: Bool{
        didSet{
            updateSelection()
        }
    }
    
    public override var isHighlighted: Bool{
        didSet{
            updateSelection()
        }
    }
    
    private func updateSelection(){
        UIView.animate(withDuration: PHConfigs.kCellAnimateDuration) {
            if self.isSelected || self.isHighlighted{
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.4)
            }
            else{
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.04)
            }
        }
    }

}
