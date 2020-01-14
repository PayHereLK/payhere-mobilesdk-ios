//
//  PHBottomViewController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 12/17/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import UIKit
import Alamofire
import ObjectMapper
import WebKit

public protocol PHViewControllerDelegate{
    func onResponseReceived(response : PHResponse<Any>?)
    func onErrorReceived(error : Error)
}
public class PHBottomViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet var progressBar: UIActivityIndicatorView!
    @IBOutlet var height: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var webView: WKWebView!
    @IBOutlet var bottomView: UIView!
    @IBOutlet var lblselectedMethod: UILabel!
    @IBOutlet var lblMethodPrecentTitle: UILabel!
    @IBOutlet var viewNavigationWrapper: UIView!
    
    
    public var initRequest : InitResonseRequest?
    public var isSandBoxEnabled : Bool = false
    private var initResonse : InitResponse?
    private var paymentOption : [(String , [PaymentOption])] {
        
        get{
            return [
                ("Credit/Debit Card" ,
                 [PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA"),PaymentOption(name: "Master", image: getImage(withImageName: "master"), optionValue: "MASTER"),PaymentOption(name: "Amex", image: getImage(withImageName: "amex"), optionValue: "AMEX"),PaymentOption(name: "Discover", image: getImage(withImageName: "discover"), optionValue: "AMEX"),PaymentOption(name: "Diners Club", image: getImage(withImageName: "diners"), optionValue: "AMEX")]
                ),("Mobile Wallet",[PaymentOption(name: "Genie", image: getImage(withImageName: "genie"), optionValue: "GENIE"),PaymentOption(name: "Frimi", image: getImage(withImageName: "frimi"), optionValue: "FRIMI"),PaymentOption(name: "Ez Cash", image: getImage(withImageName: "ezcash"), optionValue: "EZCASH"),PaymentOption(name: "m Cash", image: getImage(withImageName: "mcash"), optionValue: "MCASH")]),("Internet Banking",[PaymentOption(name: "Vishwa", image: getImage(withImageName: "vishwa"), optionValue: "VISHWA"),PaymentOption(name: "HNB", image: getImage(withImageName: "hnb"), optionValue: "HNB")])]
        }
    }
    public var delegate : PHViewControllerDelegate?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        // Do any additional setup after loading the view.
        var nib = UINib(nibName: "PayOptionCollectionViewCell", bundle: Bundle(for: PHBottomViewController.self))
        self.collectionView.register(nib, forCellWithReuseIdentifier: "PayOptionCollectionViewCell")
        
        nib = UINib(nibName: "HeaderCollectionReusableView", bundle: Bundle(for: PHBottomViewController.self))
        self.collectionView.register(nib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderCollectionReusableView")
        
        
        if(isSandBoxEnabled){
            PHConfigs.setBaseUrl(url: PHConfigs.SANDBOX_URL)
        }else{
            PHConfigs.setBaseUrl(url: PHConfigs.LIVE_URL)
        }
        
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        
        calculateHeight()
        
        let tapGestrue = UITapGestureRecognizer(target: self, action: #selector(self.viewWrapperClicked))
        tapGestrue.numberOfTapsRequired = 1
        
        self.viewNavigationWrapper.addGestureRecognizer(tapGestrue)
        self.viewNavigationWrapper.isHidden = true
        
        
    }
    
    
    
    
    private func startProcess(){
        
        let validate = self.Validate()
        
        if(validate == nil){
            checkNetworkAvailability();
        }else{
            self.dismiss(animated: true, completion: {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: validate as Any])
                self.delegate?.onErrorReceived(error: error)
            })
        }
        
    }
    
    private func checkNetworkAvailability(){
        
        var connection : Bool = false
        
        let net = NetworkReachabilityManager()
        
        net?.startListening()
        
        net?.listener = { status in
            if(net?.isReachable ?? false){
                
                switch status{
                case .reachable(.ethernetOrWiFi):
                    connection = true
                    
                case .reachable(.wwan):
                    connection = true
                    
                case .notReachable:
                    connection = false
                    
                case .unknown :
                    connection = false
                    
                }
                
                if (!connection) {
                    
                    self.dismiss(animated: true, completion: {
                                   let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unable to connect to the internet"])
                                   self.delegate?.onErrorReceived(error: error)
                    })
                    
                }else{
                    //MARK:Start sending requests
                    self.sentInitRequest()
                }
            }
        }
        
    }
    
    
    
    @objc private func viewWrapperClicked(){
        
        self.webView.isHidden = true
        self.webView.loadHTMLString("", baseURL: nil)
        self.viewNavigationWrapper.isHidden = true
        
        self.collectionView.isHidden = false
        self.lblMethodPrecentTitle.isHidden = false
        
        
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bottomConstraint.constant = -height.constant
        self.view.layoutIfNeeded()
        
        startProcess()
    }
    
    
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        bottomConstraint.constant = 0
        animateChanges()
    }
    
    
    
    private func animateChanges(_ completion : (() ->())? = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            self?.view?.layoutIfNeeded()
            }, completion: { _ in completion?() })
    }
    
    
    private func calculateHeight(){
        
        let cellHeight = (((self.collectionView.frame.width - 20) / 5) - 15) * 3
        let constHeight = 45.0 + (50.0 * 3.0)
        
        let calculatedHeight = cellHeight +  CGFloat(constHeight) +  20
        
        
        
        self.height.constant = calculatedHeight
        
        
    }
    
    
    @IBAction func panGestureRegonizer(_ sender: UIPanGestureRecognizer) {
        
        if(sender.state == .changed){
            let translation = sender.translation(in: bottomView)
            self.bottomConstraint.constant = -translation.y
        }else if(sender.state == .ended){
            let velocity = sender.velocity(in: bottomView)
            let translation = sender.translation(in: bottomView)
            
            
            
            if(velocity.y > 1000.0 || translation.y > (self.height.constant / 2)){
                
                self.bottomConstraint.constant = -self.height.constant
                animateChanges { [weak self] in
                    
                    self?.dismiss(animated: true, completion: {
                        self!.delegate?.onResponseReceived(response: nil)
                    })
                }
                
            }else{
                self.bottomConstraint.constant = 0
                self.animateChanges()
            }
        }
    }
    
    
    private func sentInitRequest(){
        
        self.progressBar.isHidden = false
        self.collectionView.isHidden = true
        
        let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? "https://www.payhere.lk/pay/")/api/payment/init")
        
        Alamofire.request(request!).validate()
            .responseString{ response in
                print(response.result.value)
        }
            .responseData { (response) in
                if let data = response.data{
                    do{
                        let  temp = try newJSONDecoder().decode(InitResponse.self, from: data)
                        
                        self.initResonse = temp
                        
                        self.progressBar.isHidden = true
                        self.collectionView.isHidden = false
                        
                    }catch{
                        print(error)
                        self.dismiss(animated: true, completion: {
                            self.delegate?.onErrorReceived(error: error)
                        })
                    }
                }
        }
        
    }
    
    private func sentPaymentOptionSelected(_ submit : Submit){
        
        self.progressBar.isHidden = false
        self.collectionView.isHidden = true
        
        let request = submit.toRawRequest(url: "\(PHConfigs.BASE_URL ?? "https://www.payhere.lk/pay/")/api/payment/submit")
        
        
        Alamofire.request(request).validate()
            .responseData { (response) in
                if let data = response.data{
                    do{
                        let  temp = try newJSONDecoder().decode(SubmitResponse.self, from: data)
                        
                        self.initWebView(temp)
                        
                    }catch{
                        //MARK:TODO
                        //ERROR HANDLING
                        self.dismiss(animated: true, completion: {
                            self.delegate?.onErrorReceived(error: error)
                        })
                       
                    }
                }
        }
        
    }
    
    private func initWebView(_ submitResponse : SubmitResponse){
        
        
        
        if let url = submitResponse.data?.url{
            
            self.collectionView.isHidden = true
            self.webView.isHidden = false
            
            self.webView.contentMode = .scaleAspectFill
            self.webView.uiDelegate = self
            self.webView.navigationDelegate = self
            
            
            
            if let URL = URL(string: url){
                
                let request = URLRequest(url: URL)
                self.webView.load(request)
                self.progressBar.isHidden = false
                self.webView.isHidden = true
                
                
            }else{
                //MARK:TODO
                //ERROR HANDLING
                self.dismiss(animated: true, completion: {
                    let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    self.delegate?.onErrorReceived(error: error)
                })
            }
        }else{
            self.dismiss(animated: true, completion: {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                self.delegate?.onErrorReceived(error: error)
            })
        }
        
        
        
    }
    
    
    
    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    
    private func getImage(withImageName : String) -> UIImage{
        
        
        
        return UIImage(named: withImageName, in: Bundle(for: PHBottomViewController.self), compatibleWith: nil)!
    }
    
    
    
    private func checkStatus(orderKey : String){
        
        self.progressBar?.startAnimating()
        self.progressBar?.isHidden = false
        
        let params = [
            "order_key" : orderKey
        ]
        
        let headers = [
            "Content-Type": "application/x-www-form-urlencoded"
        ]
        
        
        Alamofire.request(PHConfigs.BASE_URL! + PHConfigs.STATUS, method: .post, parameters: params, encoding: URLEncoding.default, headers: headers)
            .responseObject{ (response: DataResponse<StatusResponse>) in
                
                if(response.result.isSuccess){
                    self.responseListner(response: response.result.value)
                }else{
                    self.responseListner(response: nil)
                }
                
        }
        
    }
    
    private func responseListner(response : StatusResponse?){
        
        guard let lastResponse = response else{
            
            self.dismiss(animated: true, completion: {
                self.delegate?.onResponseReceived(response: nil)
            })
            
            return
        }
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS || lastResponse.getStatusState() == StatusResponse.Status.FAILED){
            delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: lastResponse), message: "Payment completed. Check response data", data: lastResponse))
        }
        
        self.dismiss(animated: true, completion: {
            self.progressBar?.stopAnimating()
            self.progressBar?.isHidden = true
        })
    }
    
    private func getStatusFromResponse(lastResponse : StatusResponse) -> Int{
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            return PHResponse<Any>.STATUS_SUCCESS
        }else{
            return PHResponse<Any>.STATUS_ERROR_PAYMENT
        }
        
    }
    
    private func Validate() -> String?{
        
        if (PHConfigs.BASE_URL == nil) {
            return "BASE_URL not set";
        }
        
        if ((initRequest?.amount)! <= 0.0) {
            return "Invalid amount";
        }
        if (initRequest?.currency == nil || initRequest?.currency?.count != 3) {
            return "Invalid currency";
        }
        if (initRequest?.merchantID == nil || initRequest?.merchantID?.count == 0) {
            return "Invalid merchant ID";
        }
        
        if(initRequest?.notifyURL == nil || initRequest?.notifyURL?.count == 0){
            initRequest?.notifyURL = PHConstants.dummyUrl
        }
        
        if(initRequest?.returnURL == nil || initRequest?.returnURL?.count == 0){
            initRequest?.returnURL = PHConstants.dummyUrl
        }
        
        if(initRequest?.cancelURL == nil || initRequest?.cancelURL?.count == 0){
            initRequest?.cancelURL = PHConstants.dummyUrl
        }
        
        
        
        return nil
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension PHBottomViewController : WKUIDelegate,WKNavigationDelegate{
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        self.webView.isHidden = true
        self.progressBar.isHidden = false
        
        
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        
            if((navigationAction.request.mainDocumentURL?.absoluteString.contains("https://www.payhere.lk/pay/payment/complete"))!){
                if(self.initResonse?.data.order != nil){
                    self.checkStatus(orderKey: self.initResonse?.data.order.orderKey ?? "")
                }
            }
        
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        insertCSSString(into: webView) // 1
        self.webView.isHidden = false
        self.progressBar.isHidden = true
    }
    
    private func insertCSSString(into webView: WKWebView) {
        
        var scriptContent = "var meta = document.createElement('meta');"
        scriptContent += "meta.name='viewport';"
        scriptContent += "meta.content='width=device-width';"
        scriptContent += "document.getElementsByTagName('head')[0].appendChild(meta);"
        
        webView.evaluateJavaScript(scriptContent) { (response, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.webView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)
            }
            
        }
        
        
        
    }
    
}

extension PHBottomViewController :  UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout{
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return paymentOption.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let options = paymentOption[section].1
        
        return options.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let headerTitle = paymentOption[indexPath.section].0
        
        if let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderCollectionReusableView", for: indexPath) as? HeaderCollectionReusableView{
            sectionHeader.lblSectionTitle.text = headerTitle
            return sectionHeader
        }
        
        
        return UICollectionReusableView()
    }
    
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: 50)
    }
    
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = ((self.collectionView.frame.width - 20) / 5) - 15
        
        
        return CGSize(width: width, height: width)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PayOptionCollectionViewCell", for: indexPath) as! PayOptionCollectionViewCell
        
        let payOption = paymentOption[indexPath.section].1[indexPath.row]
        
        cell.imgOptionImage.image = payOption.image
        
        
        
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let payOption = paymentOption[indexPath.section].1[indexPath.row]
        
        
        let submit =  Submit(key: initResonse?.data.order.orderKey ?? "", method: payOption.optionValue)
        
        sentPaymentOptionSelected(submit)
        
        self.viewNavigationWrapper.isHidden = false
        self.lblMethodPrecentTitle.isHidden = true
        self.lblselectedMethod.text = paymentOption[indexPath.section].0
        
    }
}

private struct PaymentOption {
    var name : String
    var image : UIImage
    var optionValue : String
    
}

private struct Submit : Mappable{
    
    var key : String?
    var method : String?
    
    public init?(map: Map) {
        
    }
    
    public init(key : String, method : String){
        self.key = key
        self.method = method
    }
    
    public mutating func mapping(map: Map) {
        key <- map["key"]
        method <- map["method"]
    }
    
}

extension Submit{
    
    func toRawRequest(url : String) -> URLRequest{
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pjson = self.toJSONString(prettyPrint: false)
        
        let data = (pjson?.data(using: .utf8))! as Data
        
        request.httpBody = data
        
        
        return request
        
    }
    
}

private class SubmitResponse: Codable {
    var status: Int?
    var msg: String?
    var data: SubmitDataClass?
    
    init(status: Int?, msg: String?, data: SubmitDataClass?) {
        self.status = status
        self.msg = msg
        self.data = data
    }
}

// MARK: - DataClass
private class SubmitDataClass: Codable {
    var redirectType: String?
    var url: String?
    
    init(redirectType: String?, url: String?) {
        self.redirectType = redirectType
        self.url = url
    }
}



