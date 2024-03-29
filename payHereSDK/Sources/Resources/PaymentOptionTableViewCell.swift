//
//  PaymentOptionTableViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2022-01-04.
//  Copyright © 2022 PayHere. All rights reserved.
//

import UIKit


protocol PaymentOptionTableViewCellDelegate: AnyObject{
    func didSelectedPaymentOption(paymentMethod : PaymentMethod,selectedSection : Int)
}
class PaymentOptionTableViewCell: UITableViewCell {
    
    private var list : [PaymentMethod] = []
    private var sectionID : Int = 0
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate : PaymentOptionTableViewCellDelegate?
    
    
    public static func dequeue(fromTableView tv: UITableView,list : [PaymentMethod],indexPath path : IndexPath,delegate : PaymentOptionTableViewCellDelegate) -> PaymentOptionTableViewCell{
        let cell = tv.dequeueReusableCell(withIdentifier: "PaymentOptionTableViewCell") as! PaymentOptionTableViewCell
        cell.list = list
        cell.selectionStyle = .none
        cell.delegate = delegate
        cell.collectionView.reloadData()
        cell.sectionID = path.section
        return cell
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    override func layoutSubviews() {
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}

extension PaymentOptionTableViewCell {
    
    private func setupUI() {
        
        // layout.minimumLineSpacing = 5
        // layout.minimumInteritemSpacing = 5
//        collectionViewLayout.scrollDirection = .vertical
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        
        
        let nib = UINib(nibName: "PayOptionCollectionViewCell", bundle: Bundle.payHereBundle)
        
        collectionView.register(nib, forCellWithReuseIdentifier: "PayOptionCollectionViewCell")
        
       
        collectionView.delegate = self
        collectionView.dataSource = self
        

    }
}

extension PaymentOptionTableViewCell: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return list.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PayOptionCollectionViewCell", for: indexPath) as! PayOptionCollectionViewCell
        
        let method  = list[indexPath.row]
        
        if let  url = method.view?.imageUrl{
            if let urlObj = URL(string: url){
                cell.imgOptionImage.setImage(from: urlObj, placeholder: getImage(withImageName: method.method?.lowercased() ?? "visa"))
            }
            
        }else{
            cell.imgOptionImage.image = getImage(withImageName: method.method?.lowercased() ?? "visa")
        }
        
//        cell.imgOptionImage.image = getImage(withImageName: method.method?.lowercased() ?? "visa")
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectedPaymentOption(paymentMethod: list[indexPath.row],selectedSection: sectionID)
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    private func getImage(withImageName : String) -> UIImage{
        if let image =  UIImage(named: withImageName, in: Bundle.payHereBundle, compatibleWith: nil){
            return image
        }else{
            return UIImage()
        }
    }
}

extension PaymentOptionTableViewCell: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 54, height: 54)
    }
}
