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
@preconcurrency import WebKit

public class PHBottomViewController: UIViewController {
    
    
    //MARK: TypeAlias
    
    
    //MARK: - Enum
    private enum PaymentMethodGroup: Equatable {
        case bankAccount
        case bankCard
        case other

        var title: String {
            switch self {
            case .bankAccount: return "Bank Account"
            case .bankCard: return "Bank Card"
            case .other: return "Other"
            }
        }

        var navigationSection: Int {
            switch self {
            case .bankAccount: return 0
            case .bankCard: return 1
            case .other: return 2
            }
        }
    }
    
    
    //MARK: - Classes
    
    
    
    //MARK: - Structs
    
    
    
    //MARK: - Constants
    private let net = NetworkReachabilityManager(host: "payhere.lk")!

    
    
    // MARK: - Variables
    internal var initialRequest                     : PHInitialRequest?
    internal var isSandBoxEnabled                   : Bool                          = false
    internal var orgHeight                          : CGFloat                       = 0
    internal var keyBoardHeightMax                  : CGFloat                       = 0
    internal var configuration                      : PHPaymentConfiguration        = .default
    internal var networkSession: Session = AF
    internal var openPaymentURL: (URL, @escaping (Bool) -> Void) -> Void = { url, completion in
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }
    
    private var ignoreProgressBarInNextNavigation   : Bool                          = false
    private var lifecycle = PHPaymentLifecycle()
    private var statusResponse                      : StatusResponse?
    private var timer                               : Timer?
    private var statusTimer: Timer?
    private var paymentRequest: DataRequest?
    private var statusRequest: DataRequest?
    private var requestID = UUID()
    private var activeNavigation: WKNavigation?
    private var helaPayHandoffID: UUID?
    private var isHostedCardForm = false
    private var cardFormBottomSpacingReduction: CGFloat = 0
    private var cardFormContentHeight: CGFloat?
    private var paymentWebBaselineHeight: CGFloat?
    private var webPageTargetHeight: CGFloat?
    private var webContentSizeObservation: NSKeyValueObservation?
    private var webLayoutWork: DispatchWorkItem?
    private var webLayoutRevision = 0
    private var webMeasurementInFlight = false
    private var webLayoutRequested = false
    private var webDocumentID: String?
    private var pendingWebMeasurement: PHWebContentMeasurement?
    private var nativeContainerSize: CGSize?
    private var nativeContainerInsets: UIEdgeInsets?
    private var nativeDetentHeight: CGFloat?
    private var nativeKeyboardFrame: CGRect?
    private var nativeContentSize: CGSize?
    private var dashboardRestingHeight: CGFloat?
    private weak var nativeSizingView: UIView?
    internal var usesNativeSheet: Bool { nativeContainerSize != nil }

    private var layoutContainerSize: CGSize { nativeContainerSize ?? view.bounds.size }
    private var layoutContainerInsets: UIEdgeInsets { nativeContainerInsets ?? view.safeAreaInsets }
    private let navigationAttempts = NSMapTable<WKNavigation, NSUUID>.weakToStrongObjects()
    private var waitUntilPaymentUI                  : WaitUntil!
    private var initialBottomConstant               : CGFloat                       = 0
    
    
    private var bankAccount                         : [PaymentMethod]               = []
    private var bankCard                            : [PaymentMethod]               = []
    private var other                               : [PaymentMethod]               = []

    private var visiblePaymentMethodGroups: [PaymentMethodGroup] {
        var groups: [PaymentMethodGroup] = []
        if !bankAccount.isEmpty { groups.append(.bankAccount) }
        if !bankCard.isEmpty { groups.append(.bankCard) }
        if !other.isEmpty { groups.append(.other) }
        return groups
    }

    private func paymentMethods(in group: PaymentMethodGroup) -> [PaymentMethod] {
        switch group {
        case .bankAccount: return bankAccount
        case .bankCard: return bankCard
        case .other: return other
        }
    }
    
    private var initRequest                         : PHInitRequest?
    private var initResponse                        : PHInitResponse?
    private var paymentUI                           : [String: PaymentMethod]       = [:]
    private var selectedPaymentOption               : PHPaymentOption?
    private var apiMethod                           : SelectedAPI                   = .CheckOut
    private var selectedPaymentMethod               : PaymentMethod?
    
    private var paymentOption                       : [PHPaymentOption] {
        
        get{
            return [
                PHPaymentOption(name: "Visa"          , image: getImage(withImageName: "visa")    , optionValue: "VISA"),
                PHPaymentOption(name: "Master"        , image: getImage(withImageName: "master")  , optionValue: "MASTER"),
                PHPaymentOption(name: "Amex"          , image: getImage(withImageName: "amex")    , optionValue: "AMEX"),
                PHPaymentOption(name: "Discover"      , image: getImage(withImageName: "discover"), optionValue: "AMEX"),
                PHPaymentOption(name: "Diners Club"   , image: getImage(withImageName: "diners")  , optionValue: "AMEX"),
                PHPaymentOption(name: "Genie"         , image: getImage(withImageName: "genie")   , optionValue: "GENIE"),
                PHPaymentOption(name: "Frimi"         , image: getImage(withImageName: "frimi")   , optionValue: "FRIMI"),
                PHPaymentOption(name: "Ez Cash"       , image: getImage(withImageName: "ezcash")  , optionValue: "EZCASH"),
                PHPaymentOption(name: "m Cash"        , image: getImage(withImageName: "mcash")   , optionValue: "MCASH"),
                PHPaymentOption(name: "Vishwa"        , image: getImage(withImageName: "vishwa")  , optionValue: "VISHWA"),
                PHPaymentOption(name: "HNB"           , image: getImage(withImageName: "hnb")     , optionValue: "HNB"),
                PHPaymentOption(name: "QPLUS"         , image: getImage(withImageName: "QPLUS")   , optionValue: "QPLUS")
            ]
            
        }
        
    }

    
    // WEAK VAR
    internal weak var delegate: PayHereSDKDelegate?
    private weak var cancellationAlert: UIAlertController?
    
    // MARK: - IBOutlets & Weak Views
    @IBOutlet private weak var progressBar: UIActivityIndicatorView!
    @IBOutlet private var height: NSLayoutConstraint!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var webView: WKWebView!
    @IBOutlet private weak var bottomView: UIView!
    @IBOutlet private weak var viewSandboxNoteBanner: UIView!
    @IBOutlet private weak var tableView: UITableView!
    
    @IBOutlet private weak var lblPayWithTitle: UILabel!
    @IBOutlet private weak var btnBackImage: UIImageView!
    @IBOutlet private weak var stackViewBackViewWrapper: UIStackView!
    
    @IBOutlet private weak var viewPaymentSucess: UIView!
    @IBOutlet private weak var viewBackground: UIView!
    
    @IBOutlet private weak var checkMark: WVCheckMark!
    @IBOutlet private weak var imgDeclined: UIImageView!
    @IBOutlet private weak var lblPaymentStatus: UILabel!
    @IBOutlet private weak var lblBottomMessage: UILabel!
    @IBOutlet private weak var lblPaymentID: UILabel!
    
    @IBOutlet private weak var btnDone: UIButton!
    @IBOutlet private weak var btnCancel: UIButton!
    @IBOutlet private weak var btnTryAgain: UIButton!
    
    private var step: PHCheckoutStep = .Dashboard

    internal func configurePresentation(from presenter: UIViewController) {
        if #available(iOS 16.0, *) {
            presenter.view.layoutIfNeeded()
            nativeSizingView = presenter.view
            nativeContainerSize = presenter.view.bounds.size
            nativeContainerInsets = presenter.view.safeAreaInsets
            modalPresentationStyle = .formSheet
            orgHeight = PHSheetHeightPolicy.dashboardHeight(containerWidth: presenter.view.bounds.width)
            if let sheet = sheetPresentationController {
                nativeDetentHeight = max(0, orgHeight - layoutContainerInsets.bottom)
                sheet.detents = [.custom(identifier: .init("payhere.content")) { [weak self] context in
                    guard let height = self?.nativeDetentHeight else { return nil }
                    return min(height, context.maximumDetentValue)
                }]
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                sheet.prefersEdgeAttachedInCompactHeight = true
                sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
                // Let UIKit match the native sheet shape for the current device and OS.
                sheet.preferredCornerRadius = nil
                sheet.delegate = self
                preferredContentSize = CGSize(width: layoutContainerSize.width, height: orgHeight)
            }
        } else {
            modalPresentationStyle = .overCurrentContext
            modalTransitionStyle = .crossDissolve
        }
    }

    private func configureNativeContent() {
        // Keep UIKit's safe-area constraints; replace only the storyboard overlay.
        let overlayConstraints = view.constraints.filter { constraint in
            (constraint.firstItem as? UIView) === bottomView ||
            (constraint.secondItem as? UIView) === bottomView ||
            (constraint.firstItem as? UIView) === viewBackground ||
            (constraint.secondItem as? UIView) === viewBackground
        }
        NSLayoutConstraint.deactivate(overlayConstraints)
        viewBackground.isHidden = true
        view.backgroundColor = UIColor.PrimaryTheme.ViewBackground
        bottomView.layer.cornerRadius = 0
        // The presentation controller owns clipping at the sheet boundary.
        bottomView.clipsToBounds = false
        bottomView.gestureRecognizers?.forEach { $0.isEnabled = false }
        NSLayoutConstraint.activate([
            bottomView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bottomView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // One passive material follows the sheet without participating in sizing.
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = UIColor.PrimaryTheme.ViewBackground.withAlphaComponent(0.2)
            glass.isInteractive = true
            let background = UIVisualEffectView(effect: glass)
            background.frame = view.bounds
            background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            background.cornerConfiguration = .corners(radius: .containerConcentric())
            background.isUserInteractionEnabled = false
            view.insertSubview(background, at: 0)
            // Opaque fills hide the material and prevent it sampling the presenter.
            view.backgroundColor = UIColor.PrimaryTheme.ViewBackground.withAlphaComponent(0.6)
            view.isOpaque = false
            bottomView.backgroundColor = .clear
            bottomView.isOpaque = false
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.underPageBackgroundColor = .clear
        }
        #endif
    }

    private func updateNativeContentHeight() {
        guard usesNativeSheet, isViewLoaded,
              lifecycle.phase != .closing, lifecycle.phase != .closed else { return }
        // UIKit grows its outer sheet around the keyboard. Keep the payment viewport
        // bounded by its resting height and the space actually visible above it.
        let visibleHeight = PHSheetHeightPolicy.keyboardVisibleHeight(
            restingHeight: orgHeight, containerHeight: view.bounds.height,
            safeAreaTop: view.safeAreaInsets.top,
            keyboardOverlap: nativeKeyboardOverlap(in: view))
        if height.constant != visibleHeight { height.constant = visibleHeight }
    }

    private func updateNativeSheetHeight(layoutChanges: (() -> Void)? = nil) {
        guard usesNativeSheet, lifecycle.phase != .closing, lifecycle.phase != .closed,
              let previousHeight = nativeDetentHeight else { return }
        if #available(iOS 16.0, *), let sheet = sheetPresentationController {
            let bottomInset = view.window == nil ? layoutContainerInsets.bottom : view.safeAreaInsets.bottom
            let target = max(0, orgHeight - bottomInset)
            preferredContentSize = CGSize(width: layoutContainerSize.width, height: orgHeight)
            guard target != previousHeight else {
                layoutChanges?()
                return
            }
            nativeDetentHeight = target
            sheet.animateChanges {
                sheet.invalidateDetents()
                layoutChanges?()
            }
        }
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateNativeSheetHeight()
        if usesNativeSheet { updateCardFormBottomInset() }
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateNativeContentHeight()
        if !usesNativeSheet, lifecycle.phase == .active, step == .Dashboard, initResponse != nil {
            // Resolve occlusion before measuring the table's adjusted insets.
            let visibleHeight = PHSheetHeightPolicy.keyboardVisibleHeight(
                restingHeight: orgHeight, containerHeight: view.bounds.height,
                safeAreaTop: view.safeAreaInsets.top, keyboardOverlap: 0)
            if height.constant != visibleHeight { height.constant = visibleHeight }
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if usesNativeSheet {
            if let source = nativeSizingView {
                nativeContainerSize = source.bounds.size
                nativeContainerInsets = source.safeAreaInsets
            }
            updateCardFormBottomInset()
            let size = webView.bounds.size
            if size.width > 0, nativeContentSize != size {
                nativeContentSize = size
                scheduleWebLayout()
            }
        }
        updateDashboardHeight()
    }
    
    // MARK: - Object Creation
    
    
    
    // MARK: - Object Life Cycle
    
    override public func viewDidLoad() {
        
        UIFont.loadFonts()
        
        super.viewDidLoad()
        
        self.lblPayWithTitle.font =  UIFont(name: "HPayBold", size: 18)
        self.lblPaymentStatus.font = UIFont(name: "HPay", size: 16)
        self.lblPaymentID.font = UIFont(name: "HPay", size: 14)
        self.lblBottomMessage.font = UIFont(name: "HPay", size: 12)
        
        self.btnDone.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        self.btnCancel.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        self.btnTryAgain.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        
        if(isSandBoxEnabled){
            PHConfigs.setBaseUrl(url: PHConfigs.SANDBOX_URL)
            self.viewSandboxNoteBanner.isHidden = false
        }else{
            PHConfigs.setBaseUrl(url: PHConfigs.LIVE_URL)
            self.viewSandboxNoteBanner.isHidden = true
        }
        
        setInitialHeight()
        
        
        self.viewPaymentSucess.isHidden = true
        
        
        self.initRequest = createInitRequest(phInitialRequest: initialRequest!)
        
        // Keyboard Notifications
        // WillShow and not Did ;) The View will run animated and smooth
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShowFunction(notification:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHideFunction(notification:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
        if usesNativeSheet {
            // Native sheet expansion can finish after its content's last layout pass.
            for name in [UIResponder.keyboardWillChangeFrameNotification,
                         UIResponder.keyboardDidChangeFrameNotification,
                         UIResponder.keyboardDidShowNotification] {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(keyboardWillShowFunction(notification:)),
                    name: name, object: nil)
            }
        }
        
        webView.backgroundColor = UIColor.PrimaryTheme.ViewBackground
        webView.scrollView.delegate = self
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.zoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        webView.isMultipleTouchEnabled = false
        
        // Inject viewport meta tag before page loads to prevent zooming
        let userScript = WKUserScript(source: PHWebViewScripts.viewport,
                                     injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)

        let cardFormLayout = WKUserScript(source: PHWebViewScripts.cardFormLayout,
                                          injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(cardFormLayout)
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: PHWebViewScripts.layoutObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.configuration.userContentController.add(PHWebLayoutMessageHandler { [weak self] message in
            guard let self = self, message.webView === self.webView, message.frameInfo.isMainFrame,
                  let documentID = message.body as? String,
                  self.webDocumentID == nil || documentID == self.webDocumentID else { return }
            self.scheduleWebLayout()
        }, name: "payhereLayoutChanged")
        webContentSizeObservation = webView.scrollView.observe(\.contentSize, options: [.old, .new]) { [weak self] _, change in
            guard change.oldValue != change.newValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.updateCardFormBottomInset()
                self?.scheduleWebLayout()
            }
        }
        
        
        let helaPayNib = UINib(nibName: "PayWithHelaPayTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(helaPayNib, forCellReuseIdentifier: "PayWithHelaPayTableViewCell")
        
        let paymentOptionNib = UINib(nibName: "PaymentOptionTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(paymentOptionNib, forCellReuseIdentifier: "PaymentOptionTableViewCell")
        
        let nib = UINib(nibName: "PHBottomSheetTableViewSectioHeader", bundle: Bundle.payHereBundle)
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "PHBottomSheetTableViewSectioHeader")
        
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        // These rows and section heights are explicit. Estimates otherwise leave
        // the initial grouped-table extent dependent on which rows are visible.
        self.tableView.estimatedRowHeight = 0
        self.tableView.estimatedSectionHeaderHeight = 0
        self.tableView.estimatedSectionFooterHeight = 0

        self.bottomView.layer.cornerRadius = 32
        self.bottomView.layer.cornerCurve = .continuous
        self.bottomView.layer.masksToBounds = true
        
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 0.00001))
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(backButtonClicked))
        stackViewBackViewWrapper.addGestureRecognizer(tap)
        
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(forceClose))
        self.viewBackground.addGestureRecognizer(backgroundTap)
        
        let backgroundPan = UIPanGestureRecognizer(target: self, action: #selector(panGestureRegonizer(_:)))
        self.viewBackground.addGestureRecognizer(backgroundPan)
        if usesNativeSheet { configureNativeContent() }
    
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if lifecycle.phase == .idle {
            if !usesNativeSheet { bottomConstraint.constant = -height.constant }
            performInitialSteps()
        }
        
    }
    
    private func performInitialSteps(){
        guard lifecycle.beginAttempt() != nil else { return }
        cancelPendingWork()
        self.statusResponse = nil
        self.initResponse = nil
        // Keep the rendered height while retry loads; the new method list replaces its base.
        self.dashboardRestingHeight = nil
        self.selectedPaymentOption = nil
        self.selectedPaymentMethod = nil
        self.ignoreProgressBarInNextNavigation = false
        self.progressBar.isHidden = true
        
        if apiMethod == .CheckOut{
            self.btnBackImage.isHidden = true
        }
        
        self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        self.startProcess()
    }
    
    @objc func keyboardWillShowFunction(notification: NSNotification) {
        guard lifecycle.phase == .active, step == .Payment else { return }
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        if usesNativeSheet {
            nativeKeyboardFrame = keyboardValue.cgRectValue
            updateNativeContentHeight()
            view.layoutIfNeeded()
            updateCardFormBottomInset()
            return
        }
        
        // Ensure layout is up to date to get correct safeAreaInsets
        self.view.layoutIfNeeded()
        
        guard let window = view.window else { return }
        let keyboardViewEndFrame = view.convert(keyboardValue.cgRectValue,
                                                from: window.screen.coordinateSpace)
        let intersection = view.bounds.intersection(keyboardViewEndFrame)
        let overlap = !intersection.isNull && intersection.maxY >= view.bounds.maxY
            ? intersection.height : 0

        self.bottomConstraint.constant = overlap
        
        // Calculate available height
        // Screen Height - Safe Area Top - Overlap
        let safeAreaTop = view.safeAreaInsets.top
        let availableHeight = max(0, view.bounds.height - safeAreaTop - overlap)
        
        self.height.constant = min(self.orgHeight, availableHeight)
        updateCardFormBottomInset()
        
        self.animateChanges()
        
    }
    
    @objc func keyboardWillHideFunction(notification: NSNotification) {
        if usesNativeSheet {
            nativeKeyboardFrame = nil
            updateNativeContentHeight()
            view.layoutIfNeeded()
            updateCardFormBottomInset()
            updateNativeSheetHeight()
            return
        }
        
        self.bottomConstraint.constant = 0
        self.height.constant = self.orgHeight
        updateCardFormBottomInset()
        self.animateChanges()
        
    }
    
    private func close(animate:Bool = true,and callback: (() -> Void)? = nil){
        guard lifecycle.beginClosing() else { return }
        cancelPendingWork()
        view.isUserInteractionEnabled = false
        webView.scrollView.delegate = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webContentSizeObservation = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "payhereLayoutChanged")
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)

        let finish = {
            guard self.lifecycle.finishClosing() else { return }
            callback?()
        }
        let dismissPayment = {
            if let presenter = self.presentingViewController {
                // Dismiss the payment controller and any cancellation alert together.
                presenter.dismiss(animated: animate, completion: finish)
            } else {
                finish()
            }
        }
        
        if animate && !usesNativeSheet {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut) {
                self.bottomConstraint.constant = -self.height.constant
                self.view.layoutIfNeeded()
            }completion: { _ in
                dismissPayment()
            }
        }else {
            dismissPayment()
        }

    }

    private func cancelPendingWork() {
        requestID = UUID()
        net.stopListening()
        timer?.invalidate()
        timer = nil
        statusTimer?.invalidate()
        statusTimer = nil
        paymentRequest?.cancel()
        paymentRequest = nil
        statusRequest?.cancel()
        statusRequest = nil
        activeNavigation = nil
        helaPayHandoffID = nil
        resetWebLayoutTracking()
        paymentWebBaselineHeight = nil
        isHostedCardForm = false
        cardFormBottomSpacingReduction = 0
        webView?.scrollView.contentInset.bottom = 0
        if usesNativeSheet { webView?.scrollView.contentInsetAdjustmentBehavior = .automatic }
        webView?.stopLoading()
    }

    private func finishWithError(_ error: PHPaymentError, animate: Bool = true) {
        close(animate: animate) {
            self.delegate?.payHereSDK(didFailWith: error)
        }
    }

    private func finishWithNetworkError(_ error: AFError, responseCode: Int?,
                                        responseData: Data?, animate: Bool = true) {
        finishWithError(PHPaymentErrorMapper.network(error, responseCode: responseCode,
                                                     responseData: responseData), animate: animate)
    }

    internal func finishUserClosure() {
        switch lifecycle.phase {
        case .active:
            finishWithError(PHPaymentErrorMapper.sdk(reason: .userCancelled, code: 401))
        case .result:
            finishWithResult()
        case .idle, .closing, .closed:
            return
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
        
        
        self.apiMethod = phInitialRequest.api
        
        
        initialSubmitRequest.referer = Bundle.main.bundleIdentifier
        
        initialSubmitRequest.hash = ""
        
        return initialSubmitRequest
        
    }
    
    
    
    
    private func startProcess(){
        
        self.viewPaymentSucess.isHidden = true
        self.progressBar.isHidden = false
        self.tableView.isHidden  = true
        
        if let validation = self.Validate() {
            finishWithError(PHPaymentErrorMapper.sdk(reason: validation, code: 401), animate: false)
        } else {
            checkNetworkAvailability()
        }
        
    }
    
    private func checkNetworkAvailability() {
        let attemptID = lifecycle.attemptID
        net.startListening(onQueue: .main) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID),
                      self.paymentRequest == nil, self.initResponse == nil,
                      self.net.isReachable else { return }
                switch status {
                case .reachable:
                    self.beginInitialization()
                case .notReachable, .unknown:
                    self.finishWithError(PHPaymentErrorMapper.sdk(reason: .noInternet, code: 401), animate: false)
                }
            }
        }
    }

    private func beginInitialization() {
        net.stopListening()
        if apiMethod == .PreApproval || apiMethod == .Recurrence || apiMethod == .Authorize {
            selectedPaymentOption = PHPaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA")
            initRequest?.method = "VISA"
            sentInitNSubmitRequest()
        } else {
            handleNavigation(stepId: .Dashboard, sectionId: -1)
            sentInitRequest()
        }
    }

    
    @objc private func backButtonClicked(){
        guard lifecycle.phase == .active else { return }
        
        if(apiMethod == .CheckOut && selectedPaymentOption != nil){
            cancelPendingWork()
            
            self.selectedPaymentOption = nil
            self.selectedPaymentMethod = nil
            
            self.webView.isHidden = true
            self.tableView.isHidden = false
            
            self.progressBar.isHidden = true
            
            self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        }
        else{
            self.forceClose()
        }
         
    }
    
    @objc private func forceClose(){
        if lifecycle.phase == .result {
            finishUserClosure()
            return
        }
        guard lifecycle.phase == .active, cancellationAlert == nil else { return }
        let attemptID = lifecycle.attemptID
        let phase = lifecycle.phase
        let alert = UIAlertController(
            title: "Cancel Payment?",
            message: "This payment is still being processed!",
            preferredStyle: .alert
        )
        
        cancellationAlert = alert
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            guard let self = self, self.lifecycle.attemptID == attemptID,
                  self.lifecycle.phase == phase else { return }
            self.cancellationAlert = nil
        }))
        
        alert.addAction(UIAlertAction(title: "Exit Now", style: .destructive) { [weak self] _ in
            guard let self = self, self.lifecycle.attemptID == attemptID,
                  self.lifecycle.phase == phase else { return }
            self.finishUserClosure()
        })
        
        self.present(alert, animated: true)
        
    }
    
    
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if usesNativeSheet {
            updateNativeSheetHeight()
            return
        }
        
        bottomConstraint.constant = 0
        animateChanges()
        
    }
    
    
    
    private func animateChanges(animationBlock:(() ->())? = nil,completion : (() ->())? = nil) {
        if usesNativeSheet {
            animationBlock?()
            updateNativeSheetHeight()
            view.layoutIfNeeded()
            // UISheetPresentationController lays out its sheet during animateChanges.
            // Preserve the asynchronous handoff before the caller loads WebKit.
            DispatchQueue.main.async { completion?() }
            return
        }
        self.view.setNeedsLayout()
        self.view.setNeedsDisplay()
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            animationBlock?()
            self?.view?.layoutIfNeeded()
        }, completion: { _ in completion?() })
    }
    
    
    private func setInitialHeight(){
        
        let calculatedHeight = PHSheetHeightPolicy.dashboardHeight(
            containerWidth: nativeContainerSize?.width ?? view.frame.width)
        self.height.constant = max(calculatedHeight, dashboardRestingHeight ?? calculatedHeight)
        
        self.orgHeight = self.height.constant
        
        self.bottomView.layer.cornerRadius = usesNativeSheet ? 0 : 32
    }

    private func updateDashboardHeight() {
        // Offscreen slide-in/drag geometry is occlusion, not additional content.
        guard lifecycle.phase == .active, step == .Dashboard, initResponse != nil,
              isViewLoaded, view.window != nil, !tableView.isHidden,
              usesNativeSheet || bottomConstraint.constant == 0,
              tableView.bounds.width > 0, tableView.bounds.height > 0 else { return }
        tableView.layoutIfNeeded()
        let insets = tableView.adjustedContentInset
        let chromeHeight = bottomView.bounds.height - tableView.bounds.height
        let contentHeight = tableView.contentSize.height + insets.top +
            max(insets.bottom, layoutContainerInsets.bottom) + chromeHeight
        let scale = view.traitCollection.displayScale
        guard contentHeight.isFinite, contentHeight > 0, scale > 0 else { return }
        let seed = PHSheetHeightPolicy.dashboardHeight(
            containerWidth: nativeContainerSize?.width ?? view.frame.width)
        // Keep the original layout minimum; fit the actual grouped-table spacing
        // and safe area once. Round up to avoid a fractional-pixel scroll range.
        let restingHeight = max(seed, ceil(contentHeight * scale) / scale)
        dashboardRestingHeight = restingHeight
        let visibleHeight = PHSheetHeightPolicy.keyboardVisibleHeight(
            restingHeight: restingHeight,
            containerHeight: usesNativeSheet ? view.bounds.height : layoutContainerSize.height,
            safeAreaTop: usesNativeSheet ? view.safeAreaInsets.top : layoutContainerInsets.top,
            keyboardOverlap: 0)
        let minimumOffset = -insets.top
        let maximumOffset = max(minimumOffset, tableView.contentSize.height + insets.bottom - tableView.bounds.height)
        let offset = min(max(tableView.contentOffset.y, minimumOffset), maximumOffset)
        if tableView.contentOffset.y != offset { tableView.contentOffset.y = offset }
        guard orgHeight != restingHeight || height.constant != visibleHeight else { return }
        orgHeight = restingHeight
        if usesNativeSheet {
            updateNativeSheetHeight { [weak self] in
                self?.updateNativeContentHeight()
                self?.view.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.3, delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) { [weak self] in
                self?.height.constant = visibleHeight
                self?.view.layoutIfNeeded()
            }
        }
    }

    private func restoreNativeSheetHeight() {
        resetWebLayoutTracking()
        paymentWebBaselineHeight = nil
        isHostedCardForm = false
        cardFormBottomSpacingReduction = 0
        webView.scrollView.contentInset.bottom = 0
        if usesNativeSheet { webView.scrollView.contentInsetAdjustmentBehavior = .automatic }
        // Restore the keyboard's resting height before resigning the web view's first responder.
        setInitialHeight()
        bottomConstraint.constant = 0
        initialBottomConstant = 0
        nativeKeyboardFrame = nil
        webView.endEditing(true)
        animateChanges()
    }
    
    @IBAction func panGestureRegonizer(_ sender: UIPanGestureRecognizer) {
        guard !usesNativeSheet else { return }
        
        if sender.state == .began {
            self.initialBottomConstant = self.bottomConstraint.constant
        } else if(sender.state == .changed){
            let translation = sender.translation(in: bottomView)
            let newConstant = self.initialBottomConstant - translation.y
            
            // Prevent lifting higher than the initial state
            self.bottomConstraint.constant = min(self.initialBottomConstant, newConstant)
            
        }else if(sender.state == .ended){
            let velocity = sender.velocity(in: bottomView)
            let translation = sender.translation(in: bottomView)
            
            let screenHeight = self.view.frame.height
            let threshold = screenHeight / 3.0
            
            if(velocity.y > 1000.0 || translation.y > threshold){
                
                self.finishUserClosure()
                
            }else{
                
                self.bottomConstraint.constant = self.initialBottomConstant
                self.animateChanges()
            }
        }
    }
    
    private func sentInitRequest() {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INIT)") else { return }
        progressBar.startAnimating()
        progressBar.isHidden = false
        webView.isHidden = true
        tableView.isHidden = true
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PHInitResponse.self, from: data)
                        guard result.status == 1 else {
                            self.finishWithError(PHPaymentErrorMapper.serverRejected(
                                message: result.msg), animate: false)
                            return
                        }
                        guard let key = result.data?.order?.orderKey,
                              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              let methods = result.data?.paymentMethods else {
                            self.finishWithError(PHPaymentErrorMapper.invalidInitializationResponse(), animate: false)
                            return
                        }
                        self.initResponse = result
                        self.initalizedUI(methods)
                    } catch {
                        self.finishWithError(PHPaymentErrorMapper.sdk(reason: .invalidResponse, code: nil), animate: false)
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error, responseCode: response.response?.statusCode,
                                                responseData: response.data, animate: false)
                }
            }
        }
    }

    
    private func sentInitNSubmitRequest() {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INITNSUBMIT)") else { return }
        progressBar.startAnimating()
        progressBar.isHidden = false
        tableView.isHidden = true
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PayHereInitnSubmitResponse.self, from: data)
                        guard result.status == 1 else {
                            self.finishWithError(PHPaymentErrorMapper.serverRejected(
                                message: result.msg), animate: false)
                            return
                        }
                        guard let key = result.data?.order?.orderKey,
                              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            self.finishWithError(PHPaymentErrorMapper.invalidInitializationResponse(), animate: false)
                            return
                        }
                        self.initResponse = PHInitResponse(result)
                        self.step = .Payment
                        self.initWebView(result)
                    } catch {
                        self.finishWithError(PHPaymentErrorMapper.sdk(reason: .invalidResponse, code: nil), animate: false)
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error, responseCode: response.response?.statusCode,
                                                responseData: response.data, animate: false)
                }
            }
        }
    }

    
    private func createSubmitRequest(method: String) {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let key = initResponse?.data?.order?.orderKey, !key.isEmpty else { return }
        let submitObject = SubmitRequest()
        submitObject.method = method
        submitObject.key = key
        let request = submitObject.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID,
                      self.step == .Payment else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PayHereSubmitResponse.self, from: data)
                        self.initWebView(result)
                    } catch {
                        self.finishWithError(PHPaymentErrorMapper.sdk(reason: .invalidResponse, code: nil))
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error, responseCode: response.response?.statusCode,
                                                responseData: response.data)
                }
            }
        }
    }

    
    private func initalizedUI(_ paymentMethods : [PaymentMethod]){
        let bankCardMethods = ["MASTER", "VISA", "MASTER", "AMEX", "DISCOVER", "DINERS"]
        let supportedMethods = paymentMethods.filter { $0.method?.uppercased() != "JUSTPAY" }
        guard !supportedMethods.isEmpty,
              supportedMethods.allSatisfy({ method in
                  guard let name = method.method, method.orderNo != nil else { return false }
                  return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else {
            finishWithError(PHPaymentErrorMapper.invalidInitializationResponse(), animate: false)
            return
        }
        
        paymentUI   = [:]
        bankAccount = []
        bankCard    = []
        other       = []
        
        for method in supportedMethods{
            
            if let methodName = method.method?.uppercased(){
                
                self.paymentUI[methodName] = method
                
                if methodName == "HELAPAY"{
                    bankAccount.append(method)
                }
                else if bankCardMethods.contains(methodName){
                    bankCard.append(method)
                }
                else{
                    other.append(method)
                }
            }
        }
        
        bankCard = bankCard.sorted{ $0.orderNo! < $1.orderNo! }
        other = other.sorted{ $0.orderNo! < $1.orderNo! }
        
        self.progressBar.isHidden = true
        self.tableView.isHidden = false
        self.tableView.reloadData()
        self.view.layoutIfNeeded()
        self.updateDashboardHeight()
        
    }
    
    private func initWebView(_ submitResponse :PayHereSubmitResponse){
        
        if let url = submitResponse.data?.url{
            
            self.loadPayHereSubmitUI(url: url)
            
        }else{
            self.finishWithError(PHPaymentErrorMapper.missingPaymentURL(
                status: submitResponse.status, message: submitResponse.msg))
        }
        
    }
    
    private func loadPayHereSubmitUI(url: String){
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        self.tableView.isHidden         = true
        self.webView.isHidden           = true
        self.webView.uiDelegate         = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID, self.step == .Payment else { return }
            self.reloadWebView(url: url)
        }
    }
    
    private func reloadWebView(url: String) {
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            guard let navigation = webView.load(request) else {
                finishWithError(PHPaymentErrorMapper.paymentCannotContinue())
                return
            }
            activeNavigation = navigation
            navigationAttempts.setObject(requestID as NSUUID, forKey: navigation)
            progressBar.isHidden = false
            webView.isHidden = true
        } else {
            finishWithError(PHPaymentErrorMapper.sdk(reason: .invalidPaymentURL, code: 401))
        }
    }

    private func initWebView(_ submitResponse : PayHereInitnSubmitResponse){
        if let url = submitResponse.data?.redirection?.url{
 
            
            self.loadPayHereInitAndSubmitUI(url: url)
        }else{
            self.finishWithError(PHPaymentErrorMapper.missingPaymentURL(
                status: submitResponse.status, message: submitResponse.msg))
        }
        
    }
    
    private func loadPayHereInitAndSubmitUI(url: String){
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        self.webView.isHidden = false
        
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID, self.step == .Payment else { return }
            self.reloadWebView(url: url)
        }
    }
     
    func updateWebHeight(completion: @escaping () -> Void) {
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        
        let calculatedHeight = self.calculateWebHeight()
        
        
        
        DispatchQueue.main.async {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
            // Apply UI Changes
            self.animateChanges {
                
                self.height.constant = calculatedHeight
                self.orgHeight = calculatedHeight
                self.paymentWebBaselineHeight = calculatedHeight
                
            } completion: {
                DispatchQueue.main.async{
                    guard self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                    completion()
                }
            }

        }
    }
    
    func calculateWebHeight() -> CGFloat {
        
        // Resolve selected viewSize
        var viewSize: ViewSize?
        
        if let selectedPaymentMethod {
            viewSize = selectedPaymentMethod.view?.windowSize
        } else if let selectedOption = selectedPaymentOption,
                  let data = paymentUI[selectedOption.optionValue] {
            viewSize = data.view?.windowSize
        }
        
        // VISA as baseline
        let visaViewSize = paymentUI["VISA"]?.view?.windowSize
        
        return PHSheetHeightPolicy.initialWebHeight(
            selectedHeight: viewSize?.height, visaHeight: visaViewSize?.height,
            restingHeight: orgHeight, containerHeight: layoutContainerSize.height)
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
    
    private func startOrderStatusCheckTimer() {
        guard lifecycle.phase == .active, statusTimer == nil else { return }
        let attemptID = lifecycle.attemptID
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] firedTimer in
            DispatchQueue.main.async {
                guard let self = self else {
                    firedTimer.invalidate()
                    return
                }
                guard self.lifecycle.accepts(attemptID), self.statusTimer === firedTimer else { return }
                self.orderStatusTimerTicked()
            }
        }
    }

    private func checkStatus(orderKey: String, showProgress: Bool,
                             _ completion: ((StatusResponse?) -> Void)? = nil) {
        guard lifecycle.phase == .active, statusRequest == nil, !orderKey.isEmpty,
              initResponse?.data?.order?.orderKey == orderKey else { return }
        if showProgress {
            progressBar.startAnimating()
            progressBar.isHidden = false
        }
        let attemptID = lifecycle.attemptID
        let request = networkSession.request((PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL) + PHConfigs.STATUS,
                                             method: .post, parameters: ["order_key": orderKey],
                                             headers: ["Content-Type": "application/x-www-form-urlencoded"]).validate()
        statusRequest = request
        request.responseData(queue: .main) { [weak self, weak request] response in
            DispatchQueue.main.async {
                guard let self = self, let request = request,
                      self.lifecycle.accepts(attemptID), self.statusRequest === request else { return }
                self.statusRequest = nil
                let handler = completion ?? self.handlePaymentStatus
                switch response.result {
                case .success(let data):
                    guard let json = String(data: data, encoding: .utf8),
                          let status = Mapper<StatusResponse>().map(JSONString: json) else {
                        handler(nil)
                        return
                    }
                    handler(status)
                case .failure:
                    handler(nil)
                }
            }
        }
    }

    private func createErrorResponse<T: Mappable>(_ request: URLRequest, response:AFDataResponse<Data>) -> DataResponse<T, AFError>{
        let error: AFError = .responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        let result: Result<T, AFError> = .failure(error)
        let failedResponse = DataResponse<T, AFError>(
            request: request, response: response.response,
            data: response.data, metrics: response.metrics,
            serializationDuration: 0, result: result
        )
        
        return failedResponse
    }
                          
    private func handlePaymentStatus(response: StatusResponse?) {
        guard lifecycle.phase == .active else { return }
        guard let response = response else {
            finishWithError(PHPaymentErrorMapper.paymentStatusUnavailable())
            return
        }
        guard lifecycle.receiveTerminalStatus(response.getStatusState()) else { return }
        statusResponse = response
        cancelPendingWork()
        switch response.getStatusState() {
        case .SUCCESS?:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .FAILED?:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        default:
            break
        }
        let displayResult = { [weak self] in
            guard let self = self, self.lifecycle.phase == .result else { return }
            if self.configuration.showResultScreen {
                self.handleNavigation(stepId: .Complete, sectionId: -1)
                self.showStatus(response: response)
            } else {
                self.finishWithResult()
            }
        }
        if let alert = cancellationAlert {
            cancellationAlert = nil
            alert.dismiss(animated: false, completion: displayResult)
        } else {
            displayResult()
        }
    }

    private func finishWithResult() {
        guard lifecycle.phase == .result else { return }
        guard let response = statusResponse else {
            finishWithError(PHPaymentErrorMapper.paymentStatusUnavailable())
            return
        }
        let result = PHResponse<Any>(status: getStatusFromResponse(lastResponse: response),
                                     message: "Payment completed. Check response data", data: response)
        close {
            self.delegate?.payHereSDK(didReceive: result)
        }
    }

    private func showStatus(response : StatusResponse){
        let lastResponse = response
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            imgDeclined.isHidden = true
            checkMark.isHidden = false
            checkMark.clear()
            checkMark.start()
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.8)
            
            if self.apiMethod == .PreApproval{
                self.lblPaymentStatus.text = "Card Saved"
                self.lblPaymentID.text = String(format : "Reference ID #%.0f",lastResponse.paymentNo ?? 0.0)
                self.lblBottomMessage.text = "You’ll receive an email with above Reference ID for further reference."
                self.lblPayWithTitle.text = "Saved"
            }
            else{
                self.lblPaymentStatus.text = "Payment Approved"
                self.lblPaymentID.text = String(format : "Payment ID #%.0f",lastResponse.paymentNo ?? 0.0)
                self.lblBottomMessage.text = "You’ll receive an email with above Payment ID for further reference."
                self.lblPayWithTitle.text = "Paid"
            }
            
            btnDone.isHidden = false
            btnTryAgain.isHidden = true
            btnCancel.isHidden = true
        }
        else if(lastResponse.getStatusState() == StatusResponse.Status.AUTHORIZED){
            imgDeclined.isHidden = true
            checkMark.isHidden = false
            checkMark.clear()
            checkMark.start()
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.8)
            self.lblPaymentStatus.text = "Payment Authorized"
            self.lblBottomMessage.text = "You'll be charged once the merchant process this payment"
            self.lblPaymentID.text = String(format : lastResponse.message ?? "")
            self.lblPayWithTitle.text = "Paid"
            
            btnDone.isHidden = false
            btnTryAgain.isHidden = true
            btnCancel.isHidden = true
        }
        else{
            imgDeclined.isHidden = false
            checkMark.isHidden = true
            checkMark.clear()
            checkMark.startX()
            
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Red.withAlphaComponent(0.8)
            self.lblPaymentStatus.text = "Your bank declined the payment"
            self.lblPaymentID.text = lastResponse.message ?? "Error completing the payment"
            self.lblBottomMessage.text = "Please try again with a different card or method"
            self.lblPayWithTitle.text = "Declined"
            
            let canRetry = lifecycle.canRetry(configuration: configuration, status: lastResponse.getStatusState())
            btnDone.isHidden = canRetry
            btnTryAgain.isHidden = !canRetry
            btnCancel.isHidden = !canRetry
            if !canRetry {
                lblBottomMessage.text = "Close this window to return to the merchant."
            }
        }
        
        self.statusResponse = lastResponse
        
        timer?.invalidate()
        let attemptID = lifecycle.attemptID
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] firedTimer in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.attemptID == attemptID,
                      self.lifecycle.phase == .result, self.timer === firedTimer else { return }
                self.update()
            }
        }
    }
    
    @objc private func update() {
        finishWithResult()
    }

    
    private func getStatusFromResponse(lastResponse : StatusResponse) -> Int{
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            return PHResponse<Any>.STATUS_SUCCESS
        }else{
            return PHResponse<Any>.STATUS_ERROR_PAYMENT
        }
        
    }
    
    private func Validate() -> PHPaymentError.Reason? {
        
        if(apiMethod == .CheckOut || apiMethod == .Recurrence){
            guard let amount = initRequest?.amount, amount > 0 else {
                return .invalidAmount
            }
        }
        
        if (initRequest?.currency == nil || initRequest?.currency?.count != 3) {
            return .invalidCurrency
        }
        if (initRequest?.merchantID == nil || initRequest?.merchantID?.count == 0) {
            return .invalidMerchantID
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
    
    private func handleNavigation(stepId : PHCheckoutStep,sectionId : Int){
        let isLeavingPayment = self.step == .Payment && stepId != .Payment
        self.step = stepId
        
        switch(stepId){
        case .Dashboard:
            self.webView.stopLoading()
            self.lblPayWithTitle.text = "Pay with"
            self.btnBackImage.isHidden = false
            self.tableView.isHidden  = false
            self.progressBar.isHidden = true
            self.webView.isHidden = true
            
        case .Payment:
            
            var title = ""
            
            if sectionId == 0{
                title = "Bank Account"
            }else if sectionId == 1{
                title = "Bank Card"
            }else{
                title = "Other"
            }
            
            self.tableView.isHidden  = true
            self.webView.isHidden = true
            self.progressBar.isHidden = false
            self.lblPayWithTitle.text = title
            self.btnBackImage.isHidden = false
        case .Complete:
            self.webView.isHidden = true
            self.tableView.isHidden = true
            self.viewPaymentSucess.isHidden = false
            self.btnBackImage.isHidden = true
            self.progressBar.isHidden = true
        }

        if isLeavingPayment {
            restoreNativeSheetHeight()
        }
    }
    
    @objc private func orderStatusTimerTicked() {
        guard lifecycle.phase == .active,
              let key = initResponse?.data?.order?.orderKey, !key.isEmpty else { return }
        checkStatus(orderKey: key, showProgress: false) { [weak self] response in
            guard let self = self, let status = response?.getStatusState(),
                  status != .INIT, status != .PAYMENT else { return }
            self.handlePaymentStatus(response: response)
        }
    }

    @IBAction private func btnDoneTapped() {
        finishWithResult()
    }

    
    @IBAction private func btnCancelTapped(){
        self.finishUserClosure()
    }
    
    @IBAction private func btnTryAgainTapped(){
        guard lifecycle.canRetry(configuration: configuration, status: statusResponse?.getStatusState()) else { return }
        performInitialSteps()
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
        guard lifecycle.phase == .active, step == .Payment,
              let navigation = navigation else { return }
        if let attempt = navigationAttempts.object(forKey: navigation) {
            guard attempt as UUID == requestID else { return }
        } else {
            guard activeNavigation != nil else { return }
            navigationAttempts.setObject(requestID as NSUUID, forKey: navigation)
        }
        activeNavigation = navigation
        resetWebLayoutTracking()
        isHostedCardForm = false
        cardFormBottomSpacingReduction = 0
        webView.scrollView.contentInset.bottom = 0
        if usesNativeSheet { webView.scrollView.contentInsetAdjustmentBehavior = .automatic }
        webView.isHidden = !ignoreProgressBarInNextNavigation
        progressBar.isHidden = ignoreProgressBarInNextNavigation
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard lifecycle.phase == .active, step == .Payment else {
            decisionHandler(.cancel)
            return
        }
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        let optUrl = navigationAction.request.mainDocumentURL?.absoluteString
        ignoreProgressBarInNextNavigation = false
        if let url = optUrl {
            if url.contains(PHConstants.kLiveCompleteURL) || url.contains(PHConstants.kSandboxCompleteURL) {
                if let key = initResponse?.data?.order?.orderKey, !key.isEmpty {
                    if isSandBoxEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                            self.checkStatus(orderKey: key, showProgress: true)
                        }
                    } else {
                        checkStatus(orderKey: key, showProgress: true)
                    }
                }
            } else if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimi) {
                ignoreProgressBarInNextNavigation = true
                if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimiResponse) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self, self.lifecycle.accepts(attemptID),
                              self.requestID == operationID else {
                            decisionHandler(.cancel)
                            return
                        }
                        decisionHandler(.allow)
                    }
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    private func ownsNavigation(_ navigation: WKNavigation?) -> Bool {
        guard lifecycle.phase == .active, step == .Payment,
              let navigation = navigation, activeNavigation === navigation,
              let attempt = navigationAttempts.object(forKey: navigation) else { return false }
        return attempt as UUID == requestID
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard ownsNavigation(navigation) else { return }
        scheduleWebLayout()
        webView.isHidden = false
        progressBar.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleWebNavigationFailure(webView, navigation: navigation, error: error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleWebNavigationFailure(webView, navigation: navigation, error: error)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView, ownsNavigation(activeNavigation) else { return }
        finishWithError(PHPaymentErrorMapper.paymentCannotContinue())
    }

    private func handleWebNavigationFailure(_ webView: WKWebView, navigation: WKNavigation?, error: Error) {
        guard webView === self.webView, ownsNavigation(navigation) else { return }
        let error = error as NSError
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else { return }
        finishWithError(PHPaymentErrorMapper.paymentCannotContinue())
    }

    private func updateCardFormBottomInset() {
        guard isHostedCardForm else { return }
        let tail = effectiveCardFormBottomSpacing
        if usesNativeSheet {
            // UIKit owns the sheet frame; own only the remaining scroll padding.
            if webView.scrollView.contentInsetAdjustmentBehavior != .never {
                webView.scrollView.contentInsetAdjustmentBehavior = .never
            }
            let padding = nativeKeyboardOverlap(in: nativeSizingView) > 0
                ? nativeKeyboardOverlap(in: webView) + layoutContainerInsets.bottom
                : view.safeAreaInsets.bottom
            let inset = padding - tail
            if webView.scrollView.contentInset.bottom != inset {
                webView.scrollView.contentInset.bottom = inset
            }
            scrollViewDidScroll(webView.scrollView)
            return
        }
        // Above the keyboard, the web view loses its bottom safe area. Preserve
        // the sheet's resting padding in the scrollable content until it returns.
        let keyboardPadding = bottomConstraint.constant > 0 ? view.safeAreaInsets.bottom : 0
        let inset = keyboardPadding - tail
        if webView.scrollView.contentInset.bottom != inset { webView.scrollView.contentInset.bottom = inset }
        scrollViewDidScroll(webView.scrollView)
    }

    private var effectiveCardFormBottomSpacing: CGFloat {
        guard let contentHeight = cardFormContentHeight else { return cardFormBottomSpacingReduction }
        // WebKit's native content size has a viewport floor. On a short form that
        // already includes bottom room, cancel that empty room before adding padding.
        return max(cardFormBottomSpacingReduction, webView.scrollView.contentSize.height - contentHeight)
    }

    private func nativeKeyboardOverlap(in targetView: UIView?) -> CGFloat {
        guard let targetView = targetView, let window = targetView.window,
              let frame = nativeKeyboardFrame else { return 0 }
        let intersection = targetView.bounds.intersection(
            targetView.convert(frame, from: window.screen.coordinateSpace))
        return !intersection.isNull && intersection.maxY >= targetView.bounds.maxY
            ? intersection.height : 0
    }

    private func resetWebLayoutTracking() {
        webLayoutRevision += 1
        webLayoutWork?.cancel()
        webLayoutWork = nil
        webMeasurementInFlight = false
        webLayoutRequested = false
        webDocumentID = nil
        pendingWebMeasurement = nil
        webPageTargetHeight = nil
        cardFormContentHeight = nil
    }

    private func scheduleWebLayout() {
        guard ownsNavigation(activeNavigation), !webView.isLoading else { return }
        guard webLayoutWork == nil else { return }
        guard !webMeasurementInFlight else {
            webLayoutRequested = true
            return
        }
        let revision = webLayoutRevision
        let navigation = activeNavigation
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.webLayoutRevision == revision else { return }
            self.webLayoutWork = nil
            guard self.ownsNavigation(navigation), !self.webView.isLoading else { return }
            self.webMeasurementInFlight = true
            self.measureWebLayout(navigation: navigation, revision: revision)
        }
        webLayoutWork = work
        // Wait out intermediate redirect/layout frames; the next sample must agree.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func measureWebLayout(navigation: WKNavigation?, revision: Int) {
        let contentSize = webView.bounds.size
        webView.evaluateJavaScript(PHWebViewScripts.pageMeasurement) { [weak self] result, _ in
            guard let self = self, self.webLayoutRevision == revision,
                  self.ownsNavigation(navigation) else { return }
            self.webMeasurementInFlight = false
            let requestedAgain = self.webLayoutRequested
            self.webLayoutRequested = false
            defer { if requestedAgain { self.scheduleWebLayout() } }
            guard !self.webView.isLoading, self.webView.bounds.size == contentSize,
                  let measurement = PHWebContentMeasurement(result),
                  abs(measurement.viewportWidth - contentSize.width) <= 1 else { return }
            // WebKit's layout viewport can exclude automatic safe-area insets,
            // while native contentSize still has the full view's height as a floor.
            guard self.webDocumentID == nil || self.webDocumentID == measurement.documentID else { return }
            self.webDocumentID = measurement.documentID
            let isStable = self.pendingWebMeasurement?.matches(measurement) == true
            self.pendingWebMeasurement = measurement
            guard isStable else {
                self.scheduleWebLayout()
                return
            }
            self.applyWebMeasurement(measurement)
        }
    }

    private func applyWebMeasurement(_ measurement: PHWebContentMeasurement) {
        view.layoutIfNeeded()
        let chromeHeight = bottomView.bounds.height - webView.bounds.height
        isHostedCardForm = measurement.isCardForm
        cardFormContentHeight = measurement.isCardForm ? measurement.height : nil
        cardFormBottomSpacingReduction = measurement.isCardForm ? measurement.bottomSpacing : 0
        if !measurement.isCardForm {
            if webView.scrollView.contentInset.bottom != 0 { webView.scrollView.contentInset.bottom = 0 }
            if usesNativeSheet, webView.scrollView.contentInsetAdjustmentBehavior != .automatic {
                webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            }
        }
        updateCardFormBottomInset()
        let fittedHeight = PHSheetHeightPolicy.cardFormHeight(
            contentHeight: measurement.height, chromeHeight: chromeHeight,
            explicitBottomInset: usesNativeSheet ? -cardFormBottomSpacingReduction : webView.scrollView.contentInset.bottom,
            safeAreaBottom: layoutContainerInsets.bottom,
            containerHeight: layoutContainerSize.height, safeAreaTop: layoutContainerInsets.top)
        let targetHeight: CGFloat
        if measurement.isCardForm {
            paymentWebBaselineHeight = fittedHeight
            targetHeight = fittedHeight
        } else {
            let baseline = paymentWebBaselineHeight ?? orgHeight
            // A viewport-aligned footer is not proof that the page needs another
            // safe-area inset of height. Keep this document's established target.
            let isViewportFloor = measurement.viewportFloorBottom > 0 &&
                measurement.height <= measurement.viewportFloorBottom + 1
            let requestedHeight = isViewportFloor ? (webPageTargetHeight ?? baseline) : max(baseline, fittedHeight)
            targetHeight = min(requestedHeight, max(0, layoutContainerSize.height - layoutContainerInsets.top))
        }
        webPageTargetHeight = targetHeight
        guard abs(targetHeight - orgHeight) > 1 else { return }
        orgHeight = targetHeight
        if usesNativeSheet {
            updateNativeSheetHeight { [weak self] in
                self?.updateNativeContentHeight()
                self?.view.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.3, delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) { [weak self] in
                guard let self = self else { return }
                self.height.constant = PHSheetHeightPolicy.keyboardVisibleHeight(
                    restingHeight: self.orgHeight, containerHeight: self.layoutContainerSize.height,
                    safeAreaTop: self.layoutContainerInsets.top, keyboardOverlap: self.bottomConstraint.constant)
                self.view.layoutIfNeeded()
            }
        }
    }
    
}

extension PHBottomViewController : UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isHostedCardForm, scrollView === webView.scrollView else { return }

        // The sheet is already above the keyboard. WebKit can still include the
        // keyboard in adjustedContentInset, allowing scrolling far beyond the form.
        let minimumY = -scrollView.adjustedContentInset.top
        let bottomInset = max(scrollView.contentInset.bottom,
                              webView.safeAreaInsets.bottom - effectiveCardFormBottomSpacing)
        let maximumY = max(minimumY, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
        let offsetY = min(max(scrollView.contentOffset.y, minimumY), maximumY)
        if scrollView.contentOffset.y != offsetY {
            scrollView.contentOffset.y = offsetY
        }
    }

    // Prevent zooming by returning nil for viewForZooming
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}

@available(iOS 16.0, *)
extension PHBottomViewController: UISheetPresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return false
    }

    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        guard usesNativeSheet else { return }
        forceClose()
    }

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard usesNativeSheet, lifecycle.phase == .active || lifecycle.phase == .result else { return }
        finishUserClosure()
    }
}

extension PHBottomViewController : UITableViewDelegate,UITableViewDataSource{
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visiblePaymentMethodGroups.indices.contains(section) ? 1 : 0
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return visiblePaymentMethodGroups.count
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard visiblePaymentMethodGroups.indices.contains(section) else { return nil }
        let header = PHBottomSheetTableViewSectioHeader.dequeue(fromTableView: tableView)
        header.lblPaymentMethod.text = visiblePaymentMethodGroups[section].title
        return header
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard visiblePaymentMethodGroups.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }
        let group = visiblePaymentMethodGroups[indexPath.section]
        if group == .bankAccount {
            return PayWithHelaPayTableViewCell.dequeue(fromTableView: tableView)
        }
        return PaymentOptionTableViewCell.dequeue(
            fromTableView: tableView,
            list: paymentMethods(in: group),
            indexPath: indexPath,
            delegate: self)
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard lifecycle.phase == .active, paymentRequest == nil, step == .Dashboard,
              helaPayHandoffID == nil,
              visiblePaymentMethodGroups.indices.contains(indexPath.section),
              visiblePaymentMethodGroups[indexPath.section] == .bankAccount,
              bankAccount.indices.contains(indexPath.row) else { return }
            
            let method = bankAccount[indexPath.row]
            
            /**
             Deep link into Helakuru > HelaPay
             */
            guard let url = method.submission?.mobileUrls?.IOS,
                  let urlValue = URL(string: url), let scheme = urlValue.scheme,
                  !["http", "https"].contains(scheme.lowercased()) || urlValue.host?.isEmpty == false else {
                finishWithError(PHPaymentErrorMapper.paymentCannotContinue())
                return
            }
            let attemptID = lifecycle.attemptID
            let operationID = requestID
            let handoffID = UUID()
            helaPayHandoffID = handoffID
            openPaymentURL(urlValue) { [weak self] opened in
                DispatchQueue.main.async {
                    guard let self = self, self.lifecycle.accepts(attemptID),
                          self.requestID == operationID, self.step == .Dashboard,
                          self.helaPayHandoffID == handoffID else { return }
                    self.helaPayHandoffID = nil
                    guard opened else {
                        self.finishWithError(PHPaymentErrorMapper.paymentCannotContinue())
                        return
                    }
                    self.startOrderStatusCheckTimer()
                }
            }
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return visiblePaymentMethodGroups.indices.contains(section) ? 24 : 0
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    
}

extension PHBottomViewController : PaymentOptionTableViewCellDelegate{
    
    public func didSelectedPaymentOption(paymentMethod: PaymentMethod, selectedSection: Int) {
        guard lifecycle.phase == .active, paymentRequest == nil,
              step == .Dashboard,
              visiblePaymentMethodGroups.indices.contains(selectedSection) else { return }
        //MARK: Call Submit Method With Order Key
        
        // Stop any started HelaPay status checks before selecting a method.
        statusTimer?.invalidate()
        statusTimer = nil
        statusRequest?.cancel()
        statusRequest = nil
        
        if let temp =  self.paymentOption.filter({$0.optionValue.uppercased() == paymentMethod.method?.uppercased()}).first{
            self.selectedPaymentOption = temp
        }else{
            self.selectedPaymentOption = self.paymentOption.first
        }
        
        self.selectedPaymentMethod = paymentMethod
        
        self.handleNavigation(
            stepId: .Payment,
            sectionId: visiblePaymentMethodGroups[selectedSection].navigationSection)
        self.createSubmitRequest(method: paymentMethod.submissionCode ?? "VISA")
        
    }
    
    
}
