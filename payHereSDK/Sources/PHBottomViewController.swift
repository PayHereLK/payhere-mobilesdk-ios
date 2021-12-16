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
import AlamofireObjectMapper
import WebKit

public protocol PHViewControllerDelegate{
    func onResponseReceived(response : PHResponse<Any>?)
    func onErrorReceived(error : Error)
}
internal class PHBottomViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet var progressBar: UIActivityIndicatorView!
    @IBOutlet var height: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var webView: WKWebView!
    @IBOutlet var bottomView: UIView!
    @IBOutlet var lblselectedMethod: UILabel!
    @IBOutlet var lblMethodPrecentTitle: UILabel!
    @IBOutlet var viewNavigationWrapper: UIView!
    @IBOutlet var lblThankYou: UILabel!
    @IBOutlet var viewSandboxNoteBanner: UIView!
    
    @IBOutlet var viewPaymentSucess: UIView!
    @IBOutlet var lblPaymentID: UILabel!
    @IBOutlet var lblSecureWindow: UILabel!
    @IBOutlet weak var checkMark: WVCheckMark!
    @IBOutlet var lblPaymentStatus: UILabel!
    @IBOutlet weak var lblBottomMessage: UILabel!
    
    
    internal var initialRequest : PHInitialRequest?
    internal var isSandBoxEnabled : Bool = false
    internal var delegate : PHViewControllerDelegate?
    internal var orgHeight : CGFloat = 0
    internal var keyBoardHeightMax : CGFloat = 0
    internal var shouldShowSucessView : Bool = true
    
    private var initRequest : PHInitRequest?
    private var initRepsonse : PHInitResponse?
    private var paymentUI : PaymentUI = PaymentUI()
    private var selectedPaymentOption : PaymentOption?
    private var apiMethod : SelectedAPI = .CheckOut
    private var paymentOption : [(String , [PaymentOption])] {
        
        get{
            return [
                ("Credit/Debit Card" ,
                 [PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA"),PaymentOption(name: "Master", image: getImage(withImageName: "master"), optionValue: "MASTER"),PaymentOption(name: "Amex", image: getImage(withImageName: "amex"), optionValue: "AMEX"),PaymentOption(name: "Discover", image: getImage(withImageName: "discover"), optionValue: "AMEX"),PaymentOption(name: "Diners Club", image: getImage(withImageName: "diners"), optionValue: "AMEX")]
                ),("Mobile Wallet",[PaymentOption(name: "Genie", image: getImage(withImageName: "genie"), optionValue: "GENIE"),PaymentOption(name: "Frimi", image: getImage(withImageName: "frimi"), optionValue: "FRIMI"),PaymentOption(name: "Ez Cash", image: getImage(withImageName: "ezcash"), optionValue: "EZCASH"),PaymentOption(name: "m Cash", image: getImage(withImageName: "mcash"), optionValue: "MCASH")]),("Internet Banking",[PaymentOption(name: "Vishwa", image: getImage(withImageName: "vishwa"), optionValue: "VISHWA"),PaymentOption(name: "HNB", image: getImage(withImageName: "hnb"), optionValue: "HNB")])]
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        var nib = UINib(nibName: "PayOptionCollectionViewCell", bundle: Bundle.payHereBundle)
        self.collectionView.register(nib, forCellWithReuseIdentifier: "PayOptionCollectionViewCell")
        
        nib = UINib(nibName: "HeaderCollectionReusableView", bundle: Bundle.payHereBundle)
        self.collectionView.register(nib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderCollectionReusableView")
        
        
        if(isSandBoxEnabled){
            PHConfigs.setBaseUrl(url: PHConfigs.SANDBOX_URL)
            self.viewSandboxNoteBanner.isHidden = false
        }else{
            PHConfigs.setBaseUrl(url: PHConfigs.LIVE_URL)
            self.viewSandboxNoteBanner.isHidden = true
        }
        
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        
        calculateHeight()
        
        let tapGestrue = UITapGestureRecognizer(target: self, action: #selector(self.viewWrapperClicked))
        tapGestrue.numberOfTapsRequired = 1
        
        self.viewNavigationWrapper.addGestureRecognizer(tapGestrue)
        self.viewNavigationWrapper.isHidden = true
        self.lblThankYou.isHidden = true
        self.viewPaymentSucess.isHidden = true
        
        
        self.initRequest = createInitRequest(phInitialRequest: initialRequest!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowFunction(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil) //WillShow and not Did ;) The View will run animated and smooth
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHideFunction(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        if let data = UserDefaults().data(forKey: PHConstants.UI){
            do{
                self.paymentUI = try newJSONDecoder().decode(PaymentUI.self, from: data)
                
            }catch{
                print(error)
            }
            self.getPaymentUI()
        }else{
            self.getPaymentUI()
        }
        
        webView.scrollView.delegate = self
        
        if #available(iOS 13.0, *){
            self.collectionView.overrideUserInterfaceStyle = .light
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bottomConstraint.constant = -height.constant
        self.view.layoutIfNeeded()
        
        self.collectionView.isHidden = false
        self.progressBar.isHidden = true
        
        
        //MARK: Start PreApproval Process
        if(self.apiMethod == .PreApproval || self.apiMethod == .Recurrence || self.apiMethod == .Authorize){
            self.collectionView.isHidden = true
            self.progressBar.isHidden = true
            self.selectedPaymentOption = PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA")
            self.startProcess(paymentMethod: "VISA")
            self.lblselectedMethod.text = "Credit/Debit Card"
        }
        
        
    }
    
    @objc func keyboardWillShowFunction(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            if(keyBoardHeightMax == 0){
                keyBoardHeightMax = keyboardSize.height
            }
            
            keyBoardHeightMax = max(keyboardSize.height, keyBoardHeightMax)
            
            if((keyBoardHeightMax  + orgHeight) > self.view.frame.height){
                keyBoardHeightMax = keyBoardHeightMax / 2
            }
            
            height.constant = orgHeight + keyBoardHeightMax
            animateChanges()
            
        }
        
    }
    
    @objc func keyboardWillHideFunction(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            if(keyBoardHeightMax == 0){
                keyBoardHeightMax = keyboardSize.height
            }
            
            keyBoardHeightMax = max(keyboardSize.height, keyBoardHeightMax)
            
            height.constant = orgHeight//height.constant - keyBoardHeightMax
            animateChanges()
            
        }
        
    }
    
    private func createInitRequest(phInitialRequest : PHInitialRequest) ->PHInitRequest{
        
        let initialSubmitRequest = PHInitRequest()
        
        initialSubmitRequest.merchantID = phInitialRequest.merchantID
        
        initialSubmitRequest.returnURL = PHConstants.dummyUrl
        initialSubmitRequest.cancelURL = PHConstants.dummyUrl
        
        if (phInitialRequest.notifyURL == nil || phInitialRequest.notifyURL?.count == 0){
            initialSubmitRequest.notifyURL = PHConstants.dummyUrl
        }else{
            initialSubmitRequest.notifyURL = phInitialRequest.notifyURL
        }
        
        initialSubmitRequest.firstName = phInitialRequest.firstName
        initialSubmitRequest.lastName = phInitialRequest.lastName
        initialSubmitRequest.email = phInitialRequest.email
        initialSubmitRequest.phone = phInitialRequest.phone
        
        initialSubmitRequest.address = phInitialRequest.address
        initialSubmitRequest.city = phInitialRequest.city
        initialSubmitRequest.country = phInitialRequest.country
        
        initialSubmitRequest.orderID = phInitialRequest.orderID
        initialSubmitRequest.itemsDescription = phInitialRequest.itemsDescription
        
        if(phInitialRequest.itemsMap != nil){
            
            if(phInitialRequest.itemsMap!.count > 0){
                
                var itemMap : [String : String] = [:]
                
                for (i,item) in (phInitialRequest.itemsMap?.enumerated())!{
                    
                    itemMap[String(format: "item_name_%d", i+1)] = item.name
                    itemMap[String(format: "item_number_%d", i+1)] = item.id
                    itemMap[String(format: "amount_%d", i+1)] =  String(format : "%.2f",item.amount ?? 0.0)
                    itemMap[String(format: "quantity_%d", i+1)] = String(format : "%d",item.quantity ?? 0)
                    
                }
                
                initialSubmitRequest.itemsMap = itemMap
                
            }else{
                initialSubmitRequest.itemsMap = nil
            }
            
        }else{
            initialSubmitRequest.itemsMap = nil
        }
        
        initialSubmitRequest.currency = phInitialRequest.currency?.rawValue
        if(phInitialRequest.amount == nil){
            initialSubmitRequest.amount = nil
//            self.apiMethod = .PreApproval
        }else{
            initialSubmitRequest.amount = phInitialRequest.amount
        }
        
        initialSubmitRequest.deliveryAddress = phInitialRequest.deliveryAddress
        initialSubmitRequest.deliveryCity = phInitialRequest.deliveryCity
        initialSubmitRequest.deliveryCountry = phInitialRequest.deliveryCountry
        
        initialSubmitRequest.platform = PHConstants.PLATFORM
        
        initialSubmitRequest.custom1 = phInitialRequest.custom1
        initialSubmitRequest.custom2 = phInitialRequest.custom2
        
        if(phInitialRequest.startupFee == nil){
            initialSubmitRequest.startupFee = nil
        }else{
            initialSubmitRequest.startupFee = phInitialRequest.startupFee
        }
        
        
        if(phInitialRequest.recurrence == nil){
            initialSubmitRequest.recurrence = nil
            initialSubmitRequest.auto = false
            
        }else{
            
            var recurrenceString : String = ""
            
            switch phInitialRequest.recurrence {
            case .Month(period: (let period)):
                recurrenceString = String(format : "%d Month",period)
                
            case .Week(period: (let period)):
                recurrenceString = String(format : "%d Week",period)
                
            case .Year(period: (let period)):
                recurrenceString = String(format : "%d Year",period)
                
            default:
                break
            }
            initialSubmitRequest.recurrence = recurrenceString
            initialSubmitRequest.auto = true
//            self.apiMethod = .Recurrence
        }
        
        if(phInitialRequest.duration == nil){
            initialSubmitRequest.duration = nil
            initialSubmitRequest.auto = false
            
        }else{
            
            var durationString : String = ""
            
            switch phInitialRequest.duration {
            case .Week(duration: (let duration)):
                durationString = String(format : "%d Week",duration)
                
            case .Month(duration: (let duration)):
                durationString = String(format : "%d Month",duration)
                
            case .Year(duration: (let duration)):
                durationString = String(format : "%d Year",duration)
                
            case .Forver:
                durationString = "Forever"
                
            default:
                break
            }
//            self.apiMethod = .Recurrence
            initialSubmitRequest.duration = durationString
            initialSubmitRequest.auto = true
        }
        
        
        
        initialSubmitRequest.authorize = phInitialRequest.isHoldOnCardEnabled
        
        
        self.apiMethod  = phInitialRequest.api
        
        
        initialSubmitRequest.referer = Bundle.main.bundleIdentifier
        
        initialSubmitRequest.hash = ""
        
        return initialSubmitRequest
        
    }
    
    
    
    
    private func startProcess(paymentMethod : String){
        
        self.initRequest?.method = paymentMethod
        
        let validate = self.Validate()
        
        if(validate == nil){
            checkNetworkAvailability(paymentMethod: paymentMethod);
        }else{
            self.dismiss(animated: true, completion: {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: validate as Any])
                self.delegate?.onErrorReceived(error: error)
            })
        }
        
    }
    
    private func checkNetworkAvailability(paymentMethod : String){
        
        var connection : Bool = false
        
        let net = NetworkReachabilityManager()
        
        net?.startListening(onUpdatePerforming: { (status) in
            if(net?.isReachable ?? false){
                
                switch status{
                case .reachable(.ethernetOrWiFi):
                    connection = true
                    
                case .reachable(.cellular):
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
                    self.sentInitRequest(paymentMethod: paymentMethod)
                }
            }
        })
        
        
        
    }
    
    @objc private func viewWrapperClicked(){
        
        if(apiMethod == .CheckOut){
            self.calculateHeight()
            
            self.webView.isHidden = true
            self.webView.loadHTMLString("", baseURL: nil)
            self.viewNavigationWrapper.isHidden = true
            
            self.collectionView.isHidden = false
            self.lblMethodPrecentTitle.isHidden = false
            
            self.isBackPressed = true
            self.progressBar.isHidden = true
            
        }else{
            self.dismiss(animated: true, completion: {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation Canceld"])
                self.delegate?.onErrorReceived(error: error)
            })
        }
        
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
        
        let cellHeight = (((self.view.frame.width - 20) / 5) - 15) * 3
        let constHeight = 45.0 + (50.0 * 3.0)
        let calculatedHeight = cellHeight +  CGFloat(constHeight) +  20
        self.height.constant = calculatedHeight
        
        self.orgHeight = self.height.constant
        
        
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
                    
                    self!.dismiss(animated: true, completion: {
                        let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation Canceld"])
                        self!.delegate?.onErrorReceived(error: error)
                    })
                }
                
            }else{
                self.bottomConstraint.constant = 0
                self.animateChanges()
            }
        }
    }
    
    var isBackPressed : Bool =  false
    
    private func sentInitRequest(paymentMethod : String){
        
        //TODO Submit And Init
        isBackPressed = false
        
        self.progressBar.isHidden = false
        self.collectionView.isHidden = true
        
        
        print("Url :","\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        
        let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        
        
        AF.request(request!)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PHInitResponse.self, from: data)
                        
                        if(temp.status == 1){
                            self.initRepsonse = temp
                            self.progressBar.isHidden = true
                            self.collectionView.isHidden = true
                            
                            if(!self.isBackPressed){
                                self.initWebView(self.initRepsonse!)
                            }
                            
                        }else{
                            self.dismiss(animated: true, completion: {
                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
                                self.delegate?.onErrorReceived(error: error)
                            })
                        }
                        
                        
                    }catch let err{
                        self.dismiss(animated: true, completion: {
                            self.delegate?.onErrorReceived(error: err)
                        })
                    }
                    
                case .failure(let error):
                    self.dismiss(animated: true, completion: {
                        
                        let err = NSError(domain: "", code: error.responseCode ?? 0, userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
                        
                        self.delegate?.onErrorReceived(error: err)
                    })
                }
        }
        
    }
    
    private func initWebView(_ submitResponse : PHInitResponse){
        
        self.viewNavigationWrapper.isHidden = false
        self.lblMethodPrecentTitle.isHidden = true
        
        if let url = submitResponse.data?.redirection?.url{
            
            self.collectionView.isHidden = true
            self.webView.isHidden = false
            
            self.webView.contentMode = .scaleAspectFill
            self.webView.uiDelegate = self
            self.webView.navigationDelegate = self
            
            self.calculateWebHeight()
            
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
    
    func calculateWebHeight(){
        
        let data = paymentUI.data![self.selectedPaymentOption!.optionValue]
        let visa = paymentUI.data!["VISA"]
        
        
        
        
        let selectedHeight = CGFloat(data?.viewSize?.height ?? 0)
        let visaHeight = CGFloat(visa?.viewSize?.height ?? 0)
        
        
        var calcHeight = (selectedHeight/visaHeight) * orgHeight
        
        if(calcHeight > self.view.frame.size.height){
            calcHeight = (self.view.frame.size.height - 20)
        }
        
        height.constant = calcHeight
        self.orgHeight = calcHeight
        self.animateChanges()
        
    }
    
    
    
    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                
            }
        }
        return nil
    }
    
    
    private func getImage(withImageName : String) -> UIImage{
        return UIImage(named: withImageName, in: Bundle.payHereBundle, compatibleWith: nil)!
    }
    
    private func checkStatus(orderKey : String){
        
        self.progressBar?.startAnimating()
        self.progressBar?.isHidden = false
        
        let params = [
            "order_key" : orderKey
        ]
        
        let headers : HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded"
        ]
        
        
        AF.request(PHConfigs.BASE_URL! + PHConfigs.STATUS,
                   method: .post,
                   parameters: params,
                   headers: headers).validate()
            .responseString(completionHandler: { (resonse) in
                switch resonse.result{
                case let .success(value):
                    print(value)
                case .failure(_):
                    print("Error")
                }
            })
            .responseObject(completionHandler: { (response: DataResponse<StatusResponse,AFError>) in
                switch response.result{
                case let .success(statusResponse):
                    self.responseListner(response: statusResponse)
                case .failure(_):
                    self.responseListner(response: nil)
                }
            })
    }
    
    private func responseListner(response : StatusResponse?){
        
        self.lblThankYou.isHidden = false
        self.viewNavigationWrapper.isHidden = true
        self.lblselectedMethod.isHidden = true
        self.collectionView.isHidden = true
        self.viewPaymentSucess.isHidden = false
        
        guard let lastResponse = response else{
            
            self.dismiss(animated: true, completion: {
                self.delegate?.onResponseReceived(response: nil)
            })
            
            return
        }
        
        if(shouldShowSucessView){
            
            showStatus(response: lastResponse)
            
        }else{
            
            if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS || lastResponse.getStatusState() == StatusResponse.Status.FAILED || lastResponse.getStatusState() == StatusResponse.Status.AUTHORIZED){
                delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: lastResponse), message: "Payment completed. Check response data", data: lastResponse))
            }
            
            self.dismiss(animated: true, completion: {
                self.progressBar?.stopAnimating()
                self.progressBar?.isHidden = true
            })
            
        }
    }
    
    private func showStatus(response : StatusResponse?){
        
        guard let lastResponse = response else{
            
            self.dismiss(animated: true, completion: {
                self.delegate?.onResponseReceived(response: nil)
            })
            
            return
        }
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            checkMark.clear()
            checkMark.start()
            self.lblPaymentStatus.text = "Payment Approved"
            self.lblPaymentID.text = String(format : "Payment ID #%.0f",lastResponse.paymentNo ?? 0.0)
            self.lblBottomMessage.text = "You'll receive and Email Receipt with this Payment ID for further reference"
        }else if(lastResponse.getStatusState() == StatusResponse.Status.AUTHORIZED){
            checkMark.clear()
            checkMark.start()
            self.lblPaymentStatus.text = "Payment Authorized"
            self.lblBottomMessage.text = "You'll be charged once the merchant process this payment"
            self.lblPaymentID.text = String(format : lastResponse.message ?? "")
        }else{
            checkMark.clear()
            checkMark.startX()
            self.lblPaymentStatus.text = "Payment Decline"
            self.lblPaymentID.text = lastResponse.message ?? "Error completing the payment"
            
        }
        
        self.statusResponse = lastResponse
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    private var count : Int = 5
    private var statusResponse : StatusResponse?
    private var timer : Timer?
    
    
    
    @objc private func update() {
        if(count > 0) {
            count = count - 1
            lblSecureWindow.text = String(format :"This secure payment window is closing in %d seconds...",count)
        }else{
            delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: statusResponse!), message: "Payment completed. Check response data", data: statusResponse!))
            
            self.timer?.invalidate()
            
            self.dismiss(animated: true, completion: {
                self.progressBar?.stopAnimating()
                self.progressBar?.isHidden = true
            })
        }
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
        
        if(apiMethod == .CheckOut || apiMethod == .Recurrence){
            if ((initRequest?.amount)! <= 0.0) {
                return "Invalid amount";
            }
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
        
        initRequest?.referer = Bundle.main.bundleIdentifier
        
        if(self.apiMethod == .PreApproval){
            initRequest?.auto  = true
        }else{
            initRequest?.auto = false
        }
        
      
        
        
        return nil
    }
    
    func getPaymentUI(){
        
        
        let urlRequest = URLRequest(url: URL(string: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.UI)")!)
        
        
        AF.request(urlRequest).validate()
            .responseData { (response) in
                
                switch response.result{
                case let .success(data):
                    do{
                        let  temp = try newJSONDecoder().decode(PaymentUI.self, from: data)
                        
                        if(temp.status == 1){
                            
                            UserDefaults().set(data, forKey: PHConstants.UI)
                            
                            self.paymentUI = temp
                            
                            
                        }else{
                            self.dismiss(animated: true, completion: {
                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
                                self.delegate?.onErrorReceived(error: error)
                            })
                        }
                        
                    }catch{
                        
                        self.dismiss(animated: true, completion: {
                            self.delegate?.onErrorReceived(error: error)
                        })
                    }
                    
                case .failure(_):
                    break
                }
                
        }
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
    
    internal func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        self.webView.isHidden = true
        self.progressBar.isHidden = false
        
        
    }
    
    internal func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        
        if((navigationAction.request.mainDocumentURL?.absoluteString.contains("https://www.payhere.lk/pay/payment/complete"))! || (navigationAction.request.mainDocumentURL?.absoluteString.contains("https://sandbox.payhere.lk/pay/payment/complete"))!){
            if(self.initRepsonse?.data?.order != nil){
                if isSandBoxEnabled{
                    
                    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                        self.checkStatus(orderKey: self.initRepsonse?.data!.order?.orderKey ?? "")
                    }
                    
                }else{
                    self.checkStatus(orderKey: self.initRepsonse?.data!.order?.orderKey ?? "")
                }
            }
        }
        
        decisionHandler(.allow)
    }
    
    internal func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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

extension PHBottomViewController : UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
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
        
        self.selectedPaymentOption = payOption
        // Deprecated August 2021
        // if(self.isSandBoxEnabled){
        //     startProcess(paymentMethod: "TEST")
        // }else{
        //     startProcess(paymentMethod: payOption.optionValue)
        // }
        startProcess(paymentMethod: payOption.optionValue)
        
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
