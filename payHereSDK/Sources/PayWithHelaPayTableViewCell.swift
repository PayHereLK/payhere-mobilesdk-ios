//
//  PayWithHelaPayTableViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2021-12-29.
//  Copyright © 2021 PayHere. All rights reserved.
//

import UIKit

public class PayWithHelaPayTableViewCell: UITableViewCell {
    
    public static func dequeue(fromTableView tv: UITableView) -> PayWithHelaPayTableViewCell{
        let cell = tv.dequeueReusableCell(withIdentifier: "PayWithHelaPayTableViewCell") as! PayWithHelaPayTableViewCell
        cell.selectionStyle = .none
        return cell
    }
    
    @IBOutlet private weak var viewBackground: UIView!

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        updateSelection(isSelected: true)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let touch = touches.first, frame.contains(touch.location(in: self)){
            updateSelection(isSelected: true)
        }
        else{
            updateSelection(isSelected: false)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        updateSelection(isSelected: false)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        updateSelection(isSelected: false)
    }
    
    private func updateSelection(isSelected: Bool){
        UIView.animate(withDuration: PHConfigs.kCellAnimateDuration, delay: 0.0, options: [.beginFromCurrentState]) {
            if self.isSelected {
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.4)
            }
            else{
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.04)
            }
        } completion: { (_) in
            // noop
        }
    }
    
}
