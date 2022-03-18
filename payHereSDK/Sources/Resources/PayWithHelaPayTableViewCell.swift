//
//  PayWithHelaPayTableViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2021-12-29.
//  Copyright © 2021 PayHere. All rights reserved.
//

import UIKit

class PayWithHelaPayTableViewCell: UITableViewCell {
    
    public static func dequeue(fromTableView tv: UITableView) -> PayWithHelaPayTableViewCell{
        let cell = tv.dequeueReusableCell(withIdentifier: "PayWithHelaPayTableViewCell") as! PayWithHelaPayTableViewCell
        cell.selectionStyle = .none
        return cell
    }
    
    @IBOutlet private weak var viewBackground: UIView!

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        updateSelection(isSelected: true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let touch = touches.first, frame.contains(touch.location(in: self)){
            updateSelection(isSelected: true)
        }
        else{
            updateSelection(isSelected: false)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        updateSelection(isSelected: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        updateSelection(isSelected: false)
    }
    
    private func updateSelection(isSelected: Bool){
        UIView.animate(withDuration: PHConfigs.kCellAnimateDuration, delay: 0.0, options: [.beginFromCurrentState]) {
            if isSelected{
                self.viewBackground.backgroundColor = PHConfigs.kHighlightColor
            }
            else{
                self.viewBackground.backgroundColor = PHConfigs.kNormalColor
            }
        } completion: { (_) in
            // noop
        }
    }
    
}
