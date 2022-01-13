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
    
    @IBOutlet var progressBar: UIActivityIndicatorView!
    @IBOutlet var height: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var webView: WKWebView!
    @IBOutlet var bottomView: UIView!
    @IBOutlet var viewSandboxNoteBanner: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lblPayWithTitle: UILabel!
    
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
    private var paymentOption : [PaymentOption]{
        
        get{
            return [
                PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA"),
                PaymentOption(name: "Master", image: getImage(withImageName: "master"), optionValue: "MASTER"),
                PaymentOption(name: "Amex", image: getImage(withImageName: "amex"), optionValue: "AMEX"),
                PaymentOption(name: "Discover", image: getImage(withImageName: "discover"), optionValue: "AMEX"),
                PaymentOption(name: "Diners Club", image: getImage(withImageName: "diners"), optionValue: "AMEX"),
                PaymentOption(name: "Genie", image: getImage(withImageName: "genie"), optionValue: "GENIE"),
                PaymentOption(name: "Frimi", image: getImage(withImageName: "frimi"), optionValue: "FRIMI"),
                PaymentOption(name: "Ez Cash", image: getImage(withImageName: "ezcash"), optionValue: "EZCASH"),
                PaymentOption(name: "m Cash", image: getImage(withImageName: "mcash"), optionValue: "MCASH"),
                PaymentOption(name: "Vishwa", image: getImage(withImageName: "vishwa"), optionValue: "VISHWA"),
                PaymentOption(name: "HNB", image: getImage(withImageName: "hnb"), optionValue: "HNB"),
                PaymentOption(name: "QPLUS", image: getImage(withImageName: "QPLUS"), optionValue: "QPLUS")
            ]
            
        }
    }
    
    
    
    override public func viewDidLoad() {
        
        UIFont.loadFonts()
        
        super.viewDidLoad()
        
        
        self.lblPayWithTitle.font =  UIFont(name: "HPayBold", size: 24)
        
        if(isSandBoxEnabled){
            PHConfigs.setBaseUrl(url: PHConfigs.SANDBOX_URL)
            self.viewSandboxNoteBanner.isHidden = false
        }else{
            PHConfigs.setBaseUrl(url: PHConfigs.LIVE_URL)
            self.viewSandboxNoteBanner.isHidden = true
        }
        
        
        calculateHeight()
        
        
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
        
        
        let helaPayNib = UINib(nibName: "PayWithHelaPayTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(helaPayNib, forCellReuseIdentifier: "PayWithHelaPayTableViewCell")
        
        let paymentOptionNib = UINib(nibName: "PaymentOptionTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(paymentOptionNib, forCellReuseIdentifier: "PaymentOptionTableViewCell")
        
        let nib = UINib(nibName: "PHBottomSheetTableViewSectioHeader", bundle: Bundle.payHereBundle)
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "PHBottomSheetTableViewSectioHeader")
        
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.bottomView.layer.cornerRadius = 12
        self.bottomView.layer.masksToBounds = true
        
        
        self.startProcess(paymentMethod: "VISA")
        
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 0.00001))
        
        
        //        if #available(iOS 13.0, *){
        //            self.collectionView.overrideUserInterfaceStyle = .light
        //        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bottomConstraint.constant = -height.constant
        self.view.layoutIfNeeded()
        
        //        self.collectionView.isHidden = false
        self.progressBar.isHidden = true
        
        
        //MARK: Start PreApproval Process
        if(self.apiMethod == .PreApproval || self.apiMethod == .Recurrence || self.apiMethod == .Authorize){
            //            self.collectionView.isHidden = true
            self.progressBar.isHidden = true
            self.selectedPaymentOption = PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA")
            self.startProcess(paymentMethod: "VISA")
            //            self.lblselectedMethod.text = "Credit/Debit Card"
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
        
        //        self.initRequest?.method = paymentMethod
        
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
            //            self.viewNavigationWrapper.isHidden = true
            
            //            self.collectionView.isHidden = false
            //            self.lblMethodPrecentTitle.isHidden = false
            
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
        
        self.view.layer.cornerRadius = 12
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
        //        self.collectionView.isHidden = true
        
        
        let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INIT)")
        
        AF.request(request!)
            .validate()
            .responseString{response in
                switch response.result{
                case .success(let value):
                    print(value)
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PHInitResponse.self, from: data)
                        
                        if(temp.status == 1){
                            self.initRepsonse = temp
                            self.progressBar.isHidden = true
                            //                            self.collectionView.isHidden = true
                            
                            if(!self.isBackPressed){
                                
                                self.initalizedUI(self.initRepsonse!)
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
    
    private func createSubmitRequest(method : String){
        
        let submitObject = SubmitRequest()
        
        submitObject.method = method
        submitObject.key = self.initRepsonse?.data?.order?.orderKey
        
        
        let request = submitObject.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        
        AF.request(request)
            .validate()
            .responseString{ response  in
                switch response.result{
                case .success(let data):
                    print(data)
                case .failure(let error):
                    print(error)
                }
            }
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PayHereSubmitResponse.self, from: data)
                        
                        if temp != nil{
                            self.initWebView(temp)
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
    
    var bankAccount : [PaymentMethod] = []
    var bankCard : [PaymentMethod] =  []
    var other : [PaymentMethod]  =  []
    
    private func initalizedUI(_ response : PHInitResponse){
        if let paymentMethods = response.data?.paymentMethods{
            
            for method in paymentMethods{
                
                if let methodName = method.method{
                    if methodName.uppercased() == "HELAPAY"{
                        bankAccount.append(method)
                    }else if methodName.uppercased() == "MASTER" || methodName.uppercased() == "VISA" || methodName.uppercased() == "MASTER" || methodName.uppercased() ==  "AMEX"{
                        bankCard.append(method)
                    }else{
                        other.append(method)
                    }
                }
            }
            
            self.tableView.reloadData()
        }
    }
    
    private func initWebView(_ submitResponse :PayHereSubmitResponse){
        //MARK: TODO Remove comment when submit API Precent
        
        if let url = submitResponse.data?.url{
            
            self.tableView.isHidden  = true
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
    
    private func initWebView(_ submitResponse : PHInitResponse){
        
        //        self.viewNavigationWrapper.isHidden = false
        //        self.lblMethodPrecentTitle.isHidden = true
        
        //MARK: TODO Remove comment when submit API Precent
        
        //        if let url = submitResponse.data?.redirection?.url{
        //
        ////            self.collectionView.isHidden = true
        //            self.webView.isHidden = false
        //
        //            self.webView.contentMode = .scaleAspectFill
        //            self.webView.uiDelegate = self
        //            self.webView.navigationDelegate = self
        //
        //            self.calculateWebHeight()
        //
        //            if let URL = URL(string: url){
        //
        //                let request = URLRequest(url: URL)
        //                self.webView.load(request)
        //                self.progressBar.isHidden = false
        //                self.webView.isHidden = true
        //
        //
        //            }else{
        //                //MARK:TODO
        //                //ERROR HANDLING
        //                self.dismiss(animated: true, completion: {
        //                    let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        //                    self.delegate?.onErrorReceived(error: error)
        //                })
        //            }
        //        }else{
        //            self.dismiss(animated: true, completion: {
        //                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        //                self.delegate?.onErrorReceived(error: error)
        //            })
        //        }
        
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
        return UIImage(named: withImageName, in: Bundle.payHereBundle, compatibleWith: nil)  ?? UIImage()
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
        
        //        self.lblThankYou.isHidden = false
        //        self.viewNavigationWrapper.isHidden = true
        //        self.lblselectedMethod.isHidden = true
        //        self.collectionView.isHidden = true
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

extension PHBottomViewController : UITableViewDelegate,UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0{
            return bankAccount.count > 0 ? 1:0
        }else{
            return 1
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = PHBottomSheetTableViewSectioHeader.dequeue(fromTableView: tableView)
        
        if section ==  0{
            header.lblPaymentMethod.text = "Bank Account"
        }else if section == 1{
            header.lblPaymentMethod.text = "Bank Card"
        }else{
            header.lblPaymentMethod.text = "Other"
        }
        
        
        return header
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0{
            return PayWithHelaPayTableViewCell.dequeue(fromTableView: tableView)
        }else if indexPath.section == 1{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: bankCard, delegate: self)
        }else if indexPath.section == 2{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: other,delegate: self)
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0{
            
            let method = bankAccount[indexPath.row]
            
            if let url = method.submission?.url{
                
                if let urlValue = URL(string: url){
                    UIApplication.shared.open(urlValue, options: [:], completionHandler: nil)
                }
                
                
            }
            
            
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0  && bankAccount.count > 0{
            print("Section ",section," Height : ",24)
            return 24
        }else if section == 1 && bankCard.count > 0{
            print("Section ",section," Height : ",24)
            return 24
        }else if section == 2 && other.count > 0{
            print("Section ",section," Height : ",24)
            return 24
        }else {
            print("Section ",section," Height : ",0)
            return 0.0
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    
}

extension PHBottomViewController : PaymentOptionTableViewCellDelegate{
    func didSelectedPaymentOption(paymentMethod: PaymentMethod) {
        //MARK: Call Submit Method With Order Key
        
        let selectedpayment = self.paymentOption.filter { option in
            return option.optionValue.uppercased() == paymentMethod.method?.uppercased()
        }
        
        
        if let temp =  self.paymentOption.filter{$0.optionValue.uppercased() == paymentMethod.method?.uppercased()}.first{
            self.selectedPaymentOption = temp
        }else{
            self.selectedPaymentOption = self.paymentOption.first
        }
        
        
        self.createSubmitRequest(method: paymentMethod.method ?? "VISA")
        
    }
}



private struct PaymentOption {
    var name : String
    var image : UIImage
    var optionValue : String
    
}

extension UIFont {
    private static func registerFont(withName name: String, fileExtension: String) {
        let frameworkBundle = Bundle.payHereBundle
        let pathForResourceString = frameworkBundle.path(forResource: name, ofType: fileExtension)
        let fontData = NSData(contentsOfFile: pathForResourceString!)
        let dataProvider = CGDataProvider(data: fontData!)
        let fontRef = CGFont(dataProvider!)
        var errorRef: Unmanaged<CFError>? = nil
        
        if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
            print("Error registering font")
        }
    }
    
    public static func loadFonts() {
        registerFont(withName: "HPay", fileExtension: "ttf")
        registerFont(withName: "HPayBold", fileExtension: "ttf")
    }
}
