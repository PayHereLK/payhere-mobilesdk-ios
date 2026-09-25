import XCTest
import UIKit
import WebKit
import ObjectMapper
import Alamofire
@testable import PayHereSDK

final class PHPaymentLifecycleTests: XCTestCase {
    func testConfigurationPreservesExistingDefaults() {
        let configuration = PHPaymentConfiguration.default

        XCTAssertTrue(configuration.showResultScreen)
        XCTAssertTrue(configuration.showRetryOnResultScreen)
    }

    @MainActor
    func testRetryRequiresVisibleResultAndConfirmedFailure() async {
        let statuses: [StatusResponse.Status?] = [nil, .INIT, .PAYMENT, .SUCCESS, .FAILED, .AUTHORIZED]

        for showResultScreen in [false, true] {
            for showRetryOnResultScreen in [false, true] {
                let configuration = PHPaymentConfiguration(
                    showResultScreen: showResultScreen,
                    showRetryOnResultScreen: showRetryOnResultScreen)

                for status in statuses {
                    var lifecycle = PHPaymentLifecycle()
                    _ = lifecycle.beginAttempt()
                    _ = lifecycle.receiveTerminalStatus(status)

                    XCTAssertEqual(
                        lifecycle.canRetry(configuration: configuration, status: status),
                        showResultScreen && showRetryOnResultScreen && status == .FAILED,
                        "Unexpected retry availability for status \(String(describing: status)), result \(showResultScreen), retry \(showRetryOnResultScreen)")
                }
            }
        }
    }

    @MainActor
    func testPendingAndUnavailableStatusesKeepAttemptActive() async throws {
        var lifecycle = PHPaymentLifecycle()
        let attemptID = try XCTUnwrap(lifecycle.beginAttempt())

        for status: StatusResponse.Status? in [nil, .INIT, .PAYMENT] {
            XCTAssertFalse(lifecycle.receiveTerminalStatus(status))
            XCTAssertEqual(lifecycle.phase, .active)
            XCTAssertTrue(lifecycle.accepts(attemptID))
            XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: status))
        }
    }

    @MainActor
    func testTerminalResultIsConsumedOnceAndStopsAcceptingWork() async throws {
        for status: StatusResponse.Status in [.SUCCESS, .FAILED, .AUTHORIZED] {
            var lifecycle = PHPaymentLifecycle()
            let attemptID = try XCTUnwrap(lifecycle.beginAttempt())

            XCTAssertTrue(lifecycle.receiveTerminalStatus(status))
            XCTAssertEqual(lifecycle.phase, .result)
            XCTAssertFalse(lifecycle.accepts(attemptID))
            XCTAssertFalse(lifecycle.receiveTerminalStatus(status))
            XCTAssertFalse(lifecycle.receiveTerminalStatus(.FAILED))
        }
    }

    @MainActor
    func testRetryRejectsPreviousAttemptResponses() async throws {
        var lifecycle = PHPaymentLifecycle()
        let failedAttemptID = try XCTUnwrap(lifecycle.beginAttempt())
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.FAILED))

        let retryAttemptID = try XCTUnwrap(lifecycle.beginAttempt())

        XCTAssertNotEqual(failedAttemptID, retryAttemptID)
        XCTAssertFalse(lifecycle.accepts(failedAttemptID))
        XCTAssertTrue(lifecycle.accepts(retryAttemptID))
        XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: .FAILED))
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.SUCCESS))
    }

    @MainActor
    func testClosingRejectsRepeatedActionsAndDeliversCompletionOnce() async throws {
        var lifecycle = PHPaymentLifecycle()
        let attemptID = try XCTUnwrap(lifecycle.beginAttempt())
        XCTAssertTrue(lifecycle.receiveTerminalStatus(.FAILED))

        XCTAssertTrue(lifecycle.beginClosing())
        XCTAssertEqual(lifecycle.phase, .closing)
        XCTAssertFalse(lifecycle.beginClosing())
        XCTAssertFalse(lifecycle.accepts(attemptID))
        XCTAssertNil(lifecycle.beginAttempt())
        XCTAssertFalse(lifecycle.canRetry(configuration: .default, status: .FAILED))
        XCTAssertFalse(lifecycle.receiveTerminalStatus(.SUCCESS))

        XCTAssertTrue(lifecycle.finishClosing())
        XCTAssertEqual(lifecycle.phase, .closed)
        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertFalse(lifecycle.beginClosing())
        XCTAssertNil(lifecycle.beginAttempt())
    }

    @MainActor
    func testCompletionCannotRunBeforeDismissalStarts() async {
        var lifecycle = PHPaymentLifecycle()

        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertFalse(lifecycle.receiveTerminalStatus(.SUCCESS))
        _ = lifecycle.beginAttempt()
        XCTAssertFalse(lifecycle.finishClosing())
        XCTAssertTrue(lifecycle.beginClosing())
        XCTAssertTrue(lifecycle.finishClosing())
    }

    func testMissingMalformedAndUnknownStatusesRemainUnavailable() throws {
        for payload in ["{}", "{\"status\":null}", "{\"status\":\"invalid\"}", "{\"status\":999}"] {
            let response = try XCTUnwrap(StatusResponse(JSONString: payload))

            XCTAssertNil(response.getStatusState(), payload)
        }
    }

    func testSupportedWireStatusesDecodeWithoutChangingMeaning() throws {
        for status: StatusResponse.Status in [.INIT, .PAYMENT, .SUCCESS, .FAILED, .AUTHORIZED] {
            let response = try XCTUnwrap(StatusResponse(JSON: ["status": status.rawValue]))

            XCTAssertEqual(response.getStatusState(), status)
        }
    }

    @MainActor
    func testConfigurationIsAppliedIndependentlyToEachPresentation() async throws {
        let presenter = CapturingPresenter()
        let delegate = UnexpectedPaymentDelegate()
        let configurations = [
            PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: true),
            PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: false),
            PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: true),
            PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: false)
        ]

        for configuration in configurations {
            PayHereSDK.present(from: presenter, withInitRequest: makeRequest(),
                               configuration: configuration, delegate: delegate)
        }

        XCTAssertEqual(presenter.capturedControllers.count, configurations.count)
        for (controller, expected) in zip(presenter.capturedControllers, configurations) {
            let payment = try XCTUnwrap(controller as? PHBottomViewController)
            XCTAssertEqual(payment.configuration.showResultScreen, expected.showResultScreen)
            XCTAssertEqual(payment.configuration.showRetryOnResultScreen, expected.showRetryOnResultScreen)
            XCTAssertFalse(payment.isViewLoaded, "Configuration must be assigned before checkout starts")
        }
    }

    @MainActor
    func testPresentationWithoutConfigurationMatchesExplicitDefaultConfiguration() async throws {
        let presenter = CapturingPresenter()
        let delegate = UnexpectedPaymentDelegate()

        PayHereSDK.present(from: presenter, withInitRequest: makeRequest(), delegate: delegate)
        PayHereSDK.present(from: presenter, withInitRequest: makeRequest(),
                           configuration: .default, delegate: delegate)

        XCTAssertEqual(presenter.capturedControllers.count, 2)
        for controller in presenter.capturedControllers {
            let payment = try XCTUnwrap(controller as? PHBottomViewController)
            XCTAssertTrue(payment.configuration.showResultScreen)
            XCTAssertTrue(payment.configuration.showRetryOnResultScreen)
        }
    }

    private func makeRequest() -> PHInitialRequest {
        return PHInitialRequest(merchantID: "1210000", notifyURL: nil, firstName: nil,
                                lastName: nil, email: nil, phone: nil, address: nil,
                                city: nil, country: nil, orderID: nil, itemsDescription: nil,
                                itemsMap: nil, currency: nil, amount: nil, deliveryAddress: nil,
                                deliveryCity: nil, deliveryCountry: nil, custom1: nil, custom2: nil)
    }
}

private final class CapturingPresenter: UIViewController {
    private(set) var capturedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                          completion: (() -> Void)? = nil) {
        capturedControllers.append(viewControllerToPresent)
        completion?()
    }
}

private final class UnexpectedPaymentDelegate: PayHereSDKDelegate {
    func payHereSDK(didReceive response: PHResponse<Any>) {
        XCTFail("Presentation must not complete the payment")
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        XCTFail("Unexpected presentation error: \(error)")
    }
}

// Exercises the production controller and storyboard with every SDK request intercepted.
final class PHPaymentControllerTests: XCTestCase {
    @MainActor
    func testIncompleteInitializationFailsBeforeDisplayingPaymentMethods() async throws {
        let method: [String: Any] = ["method": "VISA", "orderNo": 1, "submissionCode": "VISA"]
        let invalidData: [[String: Any]] = [
            [:],
            ["paymentMethods": [method]],
            ["order": [:], "paymentMethods": [method]],
            ["order": ["orderKey": ""], "paymentMethods": [method]],
            ["order": ["orderKey": " \n\t"], "paymentMethods": [method]],
            ["order": ["orderKey": "test-order"]],
            ["order": ["orderKey": "test-order"], "paymentMethods": NSNull()],
            ["order": ["orderKey": "test-order"], "paymentMethods": []],
            ["order": ["orderKey": "test-order"], "paymentMethods": [["method": "JUSTPAY", "orderNo": 0]]],
            ["order": ["orderKey": "test-order"], "paymentMethods": [["orderNo": 0]]]
        ]

        for data in invalidData {
            try await assertInvalidInitialization(data)
        }
    }

    @MainActor
    func testMissingAndNullPaymentMethodOrderingFailBeforeSorting() async throws {
        for explicitNull in [false, true] {
            var method: [String: Any] = ["method": "MASTER", "submissionCode": "MASTER"]
            if explicitNull { method["orderNo"] = NSNull() }
            try await assertInvalidInitialization([
                "order": ["orderKey": "test-order"],
                "paymentMethods": [["method": "VISA", "orderNo": 1], method]
            ])
        }
    }

    @MainActor
    func testInitAndSubmitWithoutOrderKeyFailsBeforeLoadingThePaymentPage() async throws {
        let payload = Data("{\"status\":1,\"data\":{\"order\":{},\"redirection\":{\"url\":\"about:blank\"}}}".utf8)
        let fixture = try makeFixture(configuration: .default, api: .PreApproval,
                                      responses: ["/pay/api/payment/initAndSubmit": .success(payload)])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .invalidResponse)
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
        XCTAssertNil(try fixture.outlet("webView", as: WKWebView.self).url)
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/initAndSubmit"])
    }

    @MainActor
    func testMissingAndInvalidHelaPayLinksFailWithoutOpeningAnApplication() async throws {
        for link: String? in [nil, "", "relative/path", "https://"] {
            let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                          responses: ["/pay/api/payment/v2/init": .success(try helaPayInitializationData(link: link))])
            do {
                let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
                fixture.controller.delegate = delegate
                fixture.controller.openPaymentURL = { _, _ in XCTFail("An invalid HelaPay link must not open an application") }
                try await waitForPaymentMethods(fixture)
                let tableView = try fixture.outlet("tableView", as: UITableView.self)
                fixture.controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                try await eventually { delegate.errorCount == 1 }
                try assertCannotContinue(delegate)
                XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init"])
            } catch {
                await fixture.stop()
                throw error
            }
            await fixture.stop()
        }
    }

    @MainActor
    func testRejectedHelaPayOpenDeliversOneErrorOnMainThreadAfterDismissal() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(try helaPayInitializationData(link: "helapay://payment/test"))])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        var completion: ((Bool) -> Void)?
        var openCount = 0
        fixture.controller.openPaymentURL = { url, callback in
            XCTAssertEqual(url.absoluteString, "helapay://payment/test")
            openCount += 1
            completion = callback
        }
        try await waitForPaymentMethods(fixture)
        let tableView = try fixture.outlet("tableView", as: UITableView.self)
        fixture.controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        fixture.controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(openCount, 1)
        let callback = try XCTUnwrap(completion)
        DispatchQueue.global().async { callback(false) }
        try await eventually { delegate.errorCount == 1 }

        try assertCannotContinue(delegate)
        callback(false)
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(delegate.errorCount, 1)
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init"])
    }

    @MainActor
    func testHelaPayPollingStartsOnlyAfterSuccessfulOpenAndIgnoresDuplicateCompletion() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(try helaPayInitializationData(link: "helapay://payment/test")),
                                                  "/pay/order_status": .success(Data("{\"status\":1}".utf8))])
        addTeardownBlock { await fixture.stop() }
        var completion: ((Bool) -> Void)?
        fixture.controller.openPaymentURL = { _, callback in completion = callback }
        try await waitForPaymentMethods(fixture)
        let tableView = try fixture.outlet("tableView", as: UITableView.self)
        fixture.controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        try await Task.sleep(nanoseconds: 3_150_000_000)
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init"])

        let callback = try XCTUnwrap(completion)
        callback(true)
        callback(false)
        try await eventually { fixture.network.requestPaths.contains("/pay/order_status") }
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
    }

    @MainActor
    func testHelaPayOpenCompletionAfterCancellationCannotRestartPollingOrReportAnotherError() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(try helaPayInitializationData(link: "helapay://payment/test"))])
        addTeardownBlock { await fixture.stop() }
        var completion: ((Bool) -> Void)?
        fixture.controller.openPaymentURL = { _, callback in completion = callback }
        try await waitForPaymentMethods(fixture)
        let tableView = try fixture.outlet("tableView", as: UITableView.self)
        fixture.controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        try await eventually { fixture.delegate.callbackCount == 1 }

        let callback = try XCTUnwrap(completion)
        callback(true)
        callback(false)
        try await Task.sleep(nanoseconds: 3_150_000_000)
        XCTAssertEqual(fixture.delegate.callbackCount, 1)
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init"])
    }

    @MainActor
    func testFirstWebNavigationFailureFailsAfterDismissalAndIgnoresCancelledAndStaleFailures() async throws {
        let fixture = try makeWebFailureFixture()
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        let webView = try await enterRecordedWebPayment(fixture)
        let initialNavigation = try XCTUnwrap(webView.navigations.last)
        let unrelatedWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let unrelatedNavigation = try XCTUnwrap(unrelatedWebView.loadHTMLString("<html></html>", baseURL: nil))
        fixture.controller.webView(webView, didFailProvisionalNavigation: initialNavigation, withError: URLError(.cancelled))
        fixture.controller.webView(webView, didFailProvisionalNavigation: unrelatedNavigation, withError: URLError(.timedOut))
        unrelatedWebView.stopLoading()
        XCTAssertEqual(webView.requests.count, 1)
        XCTAssertEqual(delegate.errorCount, 0)

        fixture.controller.webView(webView, didFailProvisionalNavigation: initialNavigation, withError: URLError(.timedOut))
        try await eventually { delegate.errorCount == 1 }
        try assertCannotContinue(delegate)

        fixture.controller.webView(webView, didFail: initialNavigation, withError: URLError(.timedOut))
        fixture.controller.webViewWebContentProcessDidTerminate(webView)
        XCTAssertEqual(delegate.errorCount, 1)
        XCTAssertEqual(webView.requests.count, 1)
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init", "/pay/api/payment/submit"])
    }

    @MainActor
    func testFirstCommittedWebFailureDeliversTypedErrorWithoutReloadingThePage() async throws {
        let fixture = try makeWebFailureFixture()
        addTeardownBlock { await fixture.stop() }
        let webView = try await enterRecordedWebPayment(fixture)
        fixture.controller.webView(webView, didFail: try XCTUnwrap(webView.navigations.last), withError: URLError(.networkConnectionLost))
        try await eventually { fixture.delegate.callbackCount == 1 }

        let error = try XCTUnwrap(fixture.delegate.error)
        XCTAssertEqual(error.reason, .paymentCannotContinue)
        XCTAssertEqual(webView.requests.count, 1)
        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
        XCTAssertNil(fixture.delegate.response)
    }

    @MainActor
    func testFirstWebProcessTerminationFailsWithoutReloadingThePage() async throws {
        let fixture = try makeWebFailureFixture()
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        let webView = try await enterRecordedWebPayment(fixture)
        fixture.controller.webViewWebContentProcessDidTerminate(webView)
        try await eventually { delegate.errorCount == 1 }

        try assertCannotContinue(delegate)
        fixture.controller.webViewWebContentProcessDidTerminate(webView)
        XCTAssertEqual(delegate.errorCount, 1)
        XCTAssertEqual(webView.requests.count, 1)
    }

    @MainActor
    func testWebFailureAfterBackCannotRetryOrFinishCheckout() async throws {
        let fixture = try makeWebFailureFixture()
        addTeardownBlock { await fixture.stop() }
        let webView = try await enterRecordedWebPayment(fixture)
        let navigation = try XCTUnwrap(webView.navigations.last)
        fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
        fixture.controller.webView(webView, didFailProvisionalNavigation: navigation, withError: URLError(.timedOut))
        fixture.controller.webViewWebContentProcessDidTerminate(webView)

        XCTAssertEqual(webView.requests.count, 1)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        XCTAssertFalse(try fixture.outlet("tableView", as: UITableView.self).isHidden)
    }

    @MainActor
    private func assertInvalidInitialization(_ data: [String: Any]) async throws {
        let payload = try JSONSerialization.data(withJSONObject: ["status": 1, "data": data])
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(payload)])
        do {
            let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
            fixture.controller.delegate = delegate
            try await eventually { delegate.errorCount == 1 }
            let error = try XCTUnwrap(delegate.error)
            XCTAssertEqual(error.reason, .invalidResponse)
            XCTAssertTrue(delegate.allCallbacksOnMainThread)
            XCTAssertTrue(delegate.errorArrivedAfterDismissal)
            XCTAssertEqual(delegate.responseCount, 0)
            XCTAssertEqual(fixture.delegate.callbackCount, 0)
            XCTAssertTrue(try fixture.outlet("tableView", as: UITableView.self).isHidden)
            XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init"])
            fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
            XCTAssertEqual(delegate.errorCount, 1)
        } catch {
            await fixture.stop()
            throw error
        }
        await fixture.stop()
    }

    @MainActor
    private func assertCannotContinue(_ delegate: TypedControllerErrorDelegate) throws {
        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .paymentCannotContinue)
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.errorCount, 1)
        XCTAssertEqual(delegate.responseCount, 0)
    }

    private func helaPayInitializationData(link: String?) throws -> Data {
        var method: [String: Any] = ["method": "HELAPAY", "orderNo": 0, "submissionCode": "HELAPAY"]
        if let link = link { method["submission"] = ["mobileUrls": ["IOS": link]] }
        return try JSONSerialization.data(withJSONObject: [
            "status": 1, "data": ["order": ["orderKey": "test-order"], "paymentMethods": [method]]
        ])
    }

    @MainActor
    private func makeWebFailureFixture() throws -> PaymentControllerFixture {
        return try makeFixture(configuration: .default, api: .CheckOut,
                               responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                           "/pay/api/payment/submit": .success(Data("{\"status\":1,\"data\":{\"url\":\"https://payments.example.invalid/start\"}}".utf8))])
    }

    @MainActor
    private func enterRecordedWebPayment(_ fixture: PaymentControllerFixture) async throws -> RecordingPaymentWebView {
        try await waitForPaymentMethods(fixture)
        let original = try fixture.outlet("webView", as: WKWebView.self)
        let webView = RecordingPaymentWebView(frame: original.frame, configuration: WKWebViewConfiguration())
        original.superview?.addSubview(webView)
        fixture.controller.setValue(webView, forKey: "webView")
        let method = try JSONDecoder().decode(PaymentMethod.self, from: Data("{\"method\":\"VISA\",\"submissionCode\":\"VISA\"}".utf8))
        fixture.controller.didSelectedPaymentOption(paymentMethod: method, selectedSection: 1)
        try await eventually { webView.requests.count == 1 }
        fixture.controller.webView(webView, didStartProvisionalNavigation: try XCTUnwrap(webView.navigations.last))
        return webView
    }

    @MainActor
    func testInitializationRejectionPreservesServerMessageInTypedCallbackAfterDismissal() async throws {
        try await assertTypedServerRejection(api: .CheckOut, path: "/pay/api/payment/v2/init",
                                            message: "  Please contact your bank.\nගෙවීම 💳", status: -41)
    }

    @MainActor
    func testInitAndSubmitRejectionPreservesEmptyServerMessageInTypedCallbackAfterDismissal() async throws {
        try await assertTypedServerRejection(api: .PreApproval, path: "/pay/api/payment/initAndSubmit",
                                            message: "", status: -12)
    }

    @MainActor
    func testInitializationSerializationFailurePreservesHTTPResponseCode() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(Data())])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate

        try await assertEmptyHTTPResponseFailure(delegate)
    }

    @MainActor
    func testInitAndSubmitSerializationFailurePreservesHTTPResponseCode() async throws {
        let fixture = try makeFixture(configuration: .default, api: .PreApproval,
                                      responses: ["/pay/api/payment/initAndSubmit": .success(Data())])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate

        try await assertEmptyHTTPResponseFailure(delegate)
    }

    @MainActor
    func testSubmissionSerializationFailurePreservesHTTPResponseCode() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(Data())])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await waitForPaymentMethods(fixture)
        let method = try JSONDecoder().decode(PaymentMethod.self, from: Data("{\"method\":\"VISA\",\"submissionCode\":\"VISA\"}".utf8))

        fixture.controller.didSelectedPaymentOption(paymentMethod: method, selectedSection: 1)

        try await assertEmptyHTTPResponseFailure(delegate)
    }

    @MainActor
    private func assertEmptyHTTPResponseFailure(_ delegate: TypedControllerErrorDelegate) async throws {
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .invalidResponse)
        XCTAssertEqual(error.code, 200)
        XCTAssertNil(error.serverMessage)
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
    }

    @MainActor
    func testSubmissionRejectionWithoutURLPreservesServerMessageAndCode() async throws {
        let message = "  Please select a different payment method.\n"
        let payload = try JSONSerialization.data(withJSONObject: ["status": -8, "msg": message])
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(payload)])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await waitForPaymentMethods(fixture)
        let method = try JSONDecoder().decode(PaymentMethod.self, from: Data("{\"method\":\"VISA\",\"submissionCode\":\"VISA\"}".utf8))
        fixture.controller.didSelectedPaymentOption(paymentMethod: method, selectedSection: 1)
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .requestRejected)
        XCTAssertEqual(error.code, 401)
        XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
        XCTAssertEqual(error.serverMessage, message)
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
    }

    @MainActor
    func testArrivingSuccessDismissesCancellationAlertAndSurvivesLateForcedClosure() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":2,\"paymentNo\":123}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        try await eventually { fixture.presentationIsSettled }
        fixture.controller.perform(NSSelectorFromString("forceClose"))
        try await eventually { fixture.alert != nil && fixture.presentationIsSettled }

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            fixture.alert == nil && fixture.presentationIsSettled &&
                (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        fixture.controller.finishUserClosure()
        fixture.controller.finishUserClosure()
        try await eventually { fixture.delegate.callbackCount == 1 }

        XCTAssertEqual((fixture.delegate.response?.getData() as? StatusResponse)?.getStatusState(), .SUCCESS)
        XCTAssertEqual((fixture.delegate.response?.getData() as? StatusResponse)?.paymentNo, 123)
        XCTAssertEqual(fixture.delegate.errorCount, 0)
        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
    }

    @MainActor
    func testMalformedInitializationResponseUsesTypedErrorWithoutExposingParserText() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(Data("{\"status\":\"not-an-integer\"}".utf8))])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .invalidResponse)
        XCTAssertNil(error.serverMessage)
        XCTAssertEqual(error.message, "We couldn’t confirm the payment details.")
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
    }

    @MainActor
    func testMalformedCompletionStatusDeliversTypedUnavailableErrorOnceAfterDismissal() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData),
                                                  "/pay/order_status": .success(Data("not-json".utf8))])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        let action = PaymentCompletionNavigationAction(url: try XCTUnwrap(URL(string: PHConstants.kSandboxCompleteURL)))

        fixture.controller.webView(webView, decidePolicyFor: action) { XCTAssertEqual($0, .allow) }
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .paymentStatusUnavailable)
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        XCTAssertEqual(delegate.errorCount, 1)
    }

    @MainActor
    func testFailedCompletionStatusDeliversTypedUnavailableErrorOnceAfterDismissal() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData),
                                                  "/pay/order_status": .failure(URLError(.timedOut))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        let action = PaymentCompletionNavigationAction(url: try XCTUnwrap(URL(string: PHConstants.kSandboxCompleteURL)))

        fixture.controller.webView(webView, decidePolicyFor: action) { XCTAssertEqual($0, .allow) }
        try await eventually { fixture.delegate.callbackCount == 1 }

        let error = try XCTUnwrap(fixture.delegate.error)
        XCTAssertEqual(error.reason, .paymentStatusUnavailable)
        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
        XCTAssertNil(fixture.delegate.response)
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        XCTAssertEqual(fixture.delegate.callbackCount, 1)
    }

    @MainActor
    private func assertTypedServerRejection(api: SelectedAPI, path: String, message: String, status: Int) async throws {
        let payload = try JSONSerialization.data(withJSONObject: ["status": status, "msg": message])
        let fixture = try makeFixture(configuration: .default, api: api,
                                      responses: [path: .success(payload)])
        addTeardownBlock { await fixture.stop() }
        let delegate = TypedControllerErrorDelegate(controller: fixture.controller)
        fixture.controller.delegate = delegate
        try await eventually { delegate.errorCount == 1 }

        let error = try XCTUnwrap(delegate.error)
        XCTAssertEqual(error.reason, .requestRejected)
        XCTAssertEqual(error.code, 501)
        XCTAssertEqual(Array(error.message.utf8), Array(message.utf8))
        XCTAssertEqual(error.serverMessage.map { Array($0.utf8) }, Array(message.utf8))
        XCTAssertTrue(delegate.allCallbacksOnMainThread)
        XCTAssertTrue(delegate.errorArrivedAfterDismissal)
        XCTAssertEqual(delegate.responseCount, 0)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        XCTAssertEqual(fixture.network.requestPaths, [path])
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        XCTAssertEqual(delegate.errorCount, 1)
    }

    @MainActor
    func testPendingStatusKeepsCheckingWithoutResultOrRetry() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":1}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually { fixture.network.requestPaths.contains("/pay/order_status") }
        // Allow the intercepted response to complete before checking the unchanged active state.
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)
        XCTAssertNil(fixture.alert)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        XCTAssertEqual(fixture.network.requestPaths, ["/pay/api/payment/v2/init", "/pay/order_status"])
    }

    @MainActor
    func testHiddenResultCompletesOnceOnMainThreadAfterDismissal() async throws {
        let fixture = try makeFixture(configuration: PHPaymentConfiguration(showResultScreen: false, showRetryOnResultScreen: true), api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":2,\"paymentNo\":123}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually { fixture.delegate.callbackCount == 1 }

        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
        XCTAssertEqual(fixture.delegate.response?.isSuccess(), true)
        XCTAssertEqual(fixture.delegate.errorCount, 0)
        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)

        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        XCTAssertEqual(fixture.delegate.callbackCount, 1)
    }

    @MainActor
    func testRetryDisabledFailureShowsDoneAndReturnsKnownFailureOnce() async throws {
        let fixture = try makeFixture(configuration: PHPaymentConfiguration(showResultScreen: true, showRetryOnResultScreen: false), api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2,\"message\":\"Declined\"}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }

        XCTAssertFalse(try fixture.outlet("btnDone", as: UIButton.self).isHidden)
        XCTAssertTrue(try fixture.outlet("btnTryAgain", as: UIButton.self).isHidden)
        XCTAssertTrue(try fixture.outlet("btnCancel", as: UIButton.self).isHidden)
        XCTAssertFalse(try fixture.outlet("lblBottomMessage", as: UILabel.self).text?.contains("try again") ?? true)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)

        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("update"))
        try await eventually { fixture.delegate.callbackCount == 1 }

        XCTAssertEqual(fixture.delegate.response?.isSuccess(), false)
        XCTAssertEqual((fixture.delegate.response?.getData() as? StatusResponse)?.getStatusState(), .FAILED)
        XCTAssertEqual((fixture.delegate.response?.getData() as? StatusResponse)?.message, "Declined")
        XCTAssertEqual(fixture.delegate.errorCount, 0)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
    }

    @MainActor
    func testCancelPreservesEveryKnownFinalResult() async throws {
        try await assertKnownResultsSurviveClosure(presentationMode: .legacy) { fixture in
            fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        }
    }

    @MainActor
    func testForceClosePreservesEveryKnownFinalResultWithoutConfirmation() async throws {
        try await assertKnownResultsSurviveClosure(presentationMode: .legacy) { fixture in
            fixture.controller.perform(NSSelectorFromString("forceClose"))
        }
    }

    @MainActor
    func testBackAfterFinalResultDoesNotDiscardItBeforeDone() async throws {
        try await assertKnownResultsSurviveClosure(presentationMode: .legacy) { fixture in
            fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
            XCTAssertEqual(fixture.delegate.callbackCount, 0)
            XCTAssertEqual(fixture.delegate.errorCount, 0)
            fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        }
    }

    @MainActor
    func testCustomPanPreservesEveryKnownFinalResult() async throws {
        try await assertKnownResultsSurviveClosure(presentationMode: .legacy) { fixture in
            fixture.controller.panGestureRegonizer(ClosingPaymentPanGesture())
        }
    }

    @MainActor
    func testNativeDismissalAttemptPreservesEveryKnownFinalResultWithoutConfirmation() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Native sheet dismissal requires iOS 16") }
        try await assertKnownResultsSurviveClosure(presentationMode: .native) { fixture in
            let sheet = try XCTUnwrap(fixture.controller.sheetPresentationController)
            fixture.controller.presentationControllerDidAttemptToDismiss(sheet)
        }
    }

    @MainActor
    func testNativeDismissalPreservesEveryKnownFinalResult() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Native sheet dismissal requires iOS 16") }
        try await assertKnownResultsSurviveClosure(presentationMode: .native) { fixture in
            let sheet = try XCTUnwrap(fixture.controller.sheetPresentationController)
            await withCheckedContinuation { continuation in
                fixture.controller.dismiss(animated: false) { continuation.resume() }
            }
            fixture.controller.presentationControllerDidDismiss(sheet)
        }
    }

    @MainActor
    private func assertKnownResultsSurviveClosure(
        presentationMode: PaymentSheetPresentationMode,
        close: (PaymentControllerFixture) async throws -> Void
    ) async throws {
        for status: StatusResponse.Status in [.SUCCESS, .AUTHORIZED, .FAILED] {
            let payload = try JSONSerialization.data(withJSONObject: [
                "status": status.rawValue, "paymentNo": 123, "message": "Final payment response"
            ])
            let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                          responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                      "/pay/order_status": .success(payload)],
                                          presentationMode: presentationMode)
            addTeardownBlock { await fixture.stop() }
            try await waitForPaymentMethods(fixture)
            fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
            try await eventually {
                fixture.presentationIsSettled &&
                    (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
            }
            XCTAssertEqual(fixture.delegate.callbackCount, 0)

            try await close(fixture)
            XCTAssertNil(fixture.alert, "A confirmed final result must not show a cancellation alert")
            try await eventually { fixture.delegate.callbackCount == 1 }

            let result = try XCTUnwrap(fixture.delegate.response?.getData() as? StatusResponse)
            XCTAssertEqual(result.getStatusState(), status)
            XCTAssertEqual(result.paymentNo, 123)
            XCTAssertEqual(result.message, "Final payment response")
            XCTAssertEqual(fixture.delegate.errorCount, 0)
            XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
            XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
            fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
            fixture.controller.perform(NSSelectorFromString("forceClose"))
            fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
            fixture.controller.perform(NSSelectorFromString("update"))
            XCTAssertEqual(fixture.delegate.callbackCount, 1)
            await fixture.stop()
        }
    }

    @MainActor
    func testRetryCancelsPreviousResultsFiveSecondDismissal() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        try await waitForPaymentMethods(fixture)

        // Cross the previous result's real timer deadline; no virtual lifecycle shortcut.
        try await Task.sleep(nanoseconds: 5_250_000_000)

        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        XCTAssertNotNil(fixture.controller.presentingViewController)
        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)
        XCTAssertEqual(fixture.network.requestPaths,
                       ["/pay/api/payment/v2/init", "/pay/order_status", "/pay/api/payment/v2/init"])
    }

    @MainActor
    func testWebResultRestoresNativeHeightAndIgnoresLateKeyboardEvents() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        let nativeHeight = fixture.controller.orgHeight
        let webHeight = try await enterWebPayment(fixture)
        XCTAssertNotEqual(webHeight, nativeHeight)
        let keyboard = try keyboardNotification(for: fixture)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        XCTAssertGreaterThan(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)
        try fixture.outlet("webView", as: WKWebView.self).scrollView.contentInset.bottom = -20

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        try assertNativeSheet(fixture, height: nativeHeight)

        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        try assertNativeSheet(fixture, height: nativeHeight)
        fixture.controller.keyboardWillHideFunction(notification: NSNotification(name: UIResponder.keyboardWillHideNotification, object: nil))
        try assertNativeSheet(fixture, height: nativeHeight)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
    }

    @MainActor
    func testBackRestoresNativeHeightAndNextPaymentUsesOriginalSizing() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        let nativeHeight = fixture.controller.orgHeight
        let firstWebHeight = try await enterWebPayment(fixture)
        let keyboard = try keyboardNotification(for: fixture)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        fixture.controller.keyboardWillHideFunction(notification: NSNotification(name: UIResponder.keyboardWillHideNotification, object: nil))
        XCTAssertEqual(try fixture.outlet("height", as: NSLayoutConstraint.self).constant, firstWebHeight, accuracy: 0.5)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)

        fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
        try assertNativeSheet(fixture, height: nativeHeight)
        XCTAssertFalse(try fixture.outlet("tableView", as: UITableView.self).isHidden)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        try assertNativeSheet(fixture, height: nativeHeight)

        let secondWebHeight = try await enterWebPayment(fixture)
        XCTAssertEqual(secondWebHeight, firstWebHeight, accuracy: 0.5)
        fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
        // Pending navigation/layout callbacks must not overwrite the restored native height.
        try await Task.sleep(nanoseconds: 350_000_000)
        try assertNativeSheet(fixture, height: nativeHeight)
    }

    @MainActor
    func testRetryReturnsToNativeHeightAfterWebPaymentFailure() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2}".utf8))])
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        let nativeHeight = fixture.controller.orgHeight
        _ = try await enterWebPayment(fixture)
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        try await waitForPaymentMethods(fixture)
        try assertNativeSheet(fixture, height: nativeHeight)
        XCTAssertTrue(try fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
    }

    @MainActor
    func testInitializedDashboardFitsAllGroupsAndPreservesSelectionBaseline() async throws {
        for mode in redirectPresentationModes {
            let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                          responses: ["/pay/api/payment/v2/init": .success(dashboardInitializationData),
                                                      "/pay/api/payment/submit": .success(webSubmissionData)],
                                          presentationMode: mode)
            do {
                try await waitForPaymentMethods(fixture)
                try await waitForDashboardLayout(fixture)
                let tableView = try fixture.outlet("tableView", as: UITableView.self)
                let bottomView = try fixture.outlet("bottomView", as: UIView.self)
                let seed = (((fixture.sourceBounds.width - 20) / 5) - 15) * 3 + 195 + 20
                let chrome = bottomView.bounds.height - tableView.bounds.height
                let bottomPadding = max(tableView.adjustedContentInset.bottom, fixture.sourceSafeAreaInsets.bottom)
                let demand = tableView.contentSize.height + tableView.adjustedContentInset.top + bottomPadding + chrome
                let expectedBase = max(seed, demand)
                let diagnostic = "native=\(fixture.controller.usesNativeSheet), seed=\(seed), " +
                    "content=\(tableView.contentSize.height), chrome=\(chrome), " +
                    "insets=\(tableView.adjustedContentInset), viewport=\(tableView.bounds.height), base=\(fixture.controller.orgHeight)"
                XCTAssertEqual(fixture.controller.orgHeight, expectedBase, accuracy: 1, diagnostic)
                XCTAssertLessThanOrEqual(tableView.contentSize.height + tableView.adjustedContentInset.top +
                                         tableView.adjustedContentInset.bottom, tableView.bounds.height + 1, diagnostic)
                if !fixture.controller.usesNativeSheet {
                    let bottomConstraint = try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self)
                    let heightConstraint = try fixture.outlet("height", as: NSLayoutConstraint.self)
                    let restingPanelHeight = bottomView.bounds.height
                    let restingConstraintHeight = heightConstraint.constant
                    let restingBottomInset = tableView.adjustedContentInset.bottom
                    // Let this fixture actually exercise offscreen geometry. The
                    // storyboard's required bottom boundary otherwise masks it.
                    let bottomBoundary = try XCTUnwrap(fixture.controller.view.constraints.first {
                        ($0.firstItem as? UIView) === fixture.controller.view &&
                        ($0.secondItem as? UIView) === bottomView &&
                        $0.firstAttribute == .bottom && $0.secondAttribute == .bottom &&
                        $0.relation == .greaterThanOrEqual
                    })
                    bottomBoundary.isActive = false
                    defer { bottomBoundary.isActive = true }
                    // Moving the panel below the window must not change its content
                    // demand, regardless of how UIKit adjusts insets on that runtime.
                    bottomConstraint.constant = -80
                    fixture.controller.view.setNeedsLayout()
                    try await waitForDashboardLayout(fixture)
                    let displacedFrame = bottomView.convert(bottomView.bounds, to: fixture.controller.view)
                    XCTAssertGreaterThan(displacedFrame.maxY, fixture.controller.view.bounds.maxY + 1,
                                         "The simulated drag must move the panel below the window")
                    XCTAssertEqual(fixture.controller.orgHeight, expectedBase, accuracy: 1,
                                   "Dragging must not overwrite the dashboard baseline")
                    XCTAssertEqual(heightConstraint.constant, restingConstraintHeight, accuracy: 1)
                    XCTAssertEqual(bottomView.bounds.height, restingPanelHeight, accuracy: 1)

                    bottomConstraint.constant = 0
                    fixture.controller.view.setNeedsLayout()
                    try await waitForDashboardLayout(fixture)
                    XCTAssertEqual(fixture.controller.orgHeight, expectedBase, accuracy: 1)
                    XCTAssertEqual(heightConstraint.constant, restingConstraintHeight, accuracy: 1)
                    XCTAssertEqual(bottomView.bounds.height, restingPanelHeight, accuracy: 1)
                    XCTAssertEqual(tableView.adjustedContentInset.bottom, restingBottomInset, accuracy: 1)
                    XCTAssertLessThanOrEqual(tableView.contentSize.height + tableView.adjustedContentInset.top +
                                             tableView.adjustedContentInset.bottom, tableView.bounds.height + 1)
                }
                XCTAssertEqual(tableView.numberOfSections, 3)
                XCTAssertEqual((0..<3).map { tableView.numberOfRows(inSection: $0) }, [1, 1, 1])
                XCTAssertTrue(tableView.cellForRow(at: IndexPath(row: 0, section: 0)) is PayWithHelaPayTableViewCell)
                let cardCell = try XCTUnwrap(tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? PaymentOptionTableViewCell)
                let otherCell = try XCTUnwrap(tableView.cellForRow(at: IndexPath(row: 0, section: 2)) as? PaymentOptionTableViewCell)
                cardCell.layoutIfNeeded()
                otherCell.layoutIfNeeded()
                let cards = try XCTUnwrap(cardCell.collectionView)
                let otherMethods = try XCTUnwrap(otherCell.collectionView)
                XCTAssertEqual(cards.numberOfItems(inSection: 0), 2)
                XCTAssertEqual(otherMethods.numberOfItems(inSection: 0), 3)

                // Select the initialized MASTER item through its real collection delegate.
                // Its server height is 320; VISA's reference height is 400.
                cards.delegate?.collectionView?(cards, didSelectItemAt: IndexPath(item: 1, section: 0))
                let webView = try fixture.outlet("webView", as: WKWebView.self)
                try await eventually { !webView.isHidden && webView.url?.absoluteString == "about:blank" }
                let expectedWebHeight = min((CGFloat(320) / 400) * expectedBase + 64, fixture.sourceBounds.height - 20)
                XCTAssertEqual(fixture.controller.orgHeight, expectedWebHeight, accuracy: 1,
                               "Server ratios must use the fitted dashboard baseline")
                fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
                try await waitForDashboardLayout(fixture)
                XCTAssertFalse(tableView.isHidden)
                XCTAssertTrue(webView.isHidden)
                XCTAssertEqual(fixture.controller.orgHeight, expectedBase, accuracy: 1,
                               "Back must restore the initialized dashboard's fitted baseline")
                XCTAssertLessThanOrEqual(tableView.contentSize.height + tableView.adjustedContentInset.top +
                                         tableView.adjustedContentInset.bottom, tableView.bounds.height + 1)
                XCTAssertEqual(fixture.network.requestPaths,
                               ["/pay/api/payment/v2/init", "/pay/api/payment/submit"])
            } catch {
                await fixture.stop()
                throw error
            }
            await fixture.stop()
        }
    }

    @MainActor
    func testInitializedDashboardOmitsUnavailablePaymentMethodSections() async throws {
        let fixture = try makeFixture(
            configuration: .default,
            api: .CheckOut,
            responses: ["/pay/api/payment/v2/init": .success(initializationData)])
        addTeardownBlock { await fixture.stop() }

        try await waitForPaymentMethods(fixture)
        let tableView = try fixture.outlet("tableView", as: UITableView.self)

        XCTAssertEqual(tableView.numberOfSections, 1)
        XCTAssertEqual(tableView.numberOfRows(inSection: 0), 1)
        let header = try XCTUnwrap(
            fixture.controller.tableView(tableView, viewForHeaderInSection: 0)
                as? PHBottomSheetTableViewSectioHeader)
        XCTAssertEqual(header.lblPaymentMethod.text, "Bank Card")

        let cardCell = try XCTUnwrap(
            tableView.cellForRow(at: IndexPath(row: 0, section: 0))
                as? PaymentOptionTableViewCell)
        cardCell.layoutIfNeeded()
        XCTAssertEqual(cardCell.collectionView.numberOfItems(inSection: 0), 1)
    }

    @MainActor
    func testInitializedDashboardKeepsEveryGroupReachableInRestrictedHeight() async throws {
        for mode in redirectPresentationModes {
            let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                          responses: ["/pay/api/payment/v2/init": .success(dashboardInitializationData)],
                                          presentationMode: mode)
            do {
                try await waitForPaymentMethods(fixture)
                try await waitForDashboardLayout(fixture)
                let view = try XCTUnwrap(fixture.controller.view)
                let tableView = try fixture.outlet("tableView", as: UITableView.self)
                let bottomView = try fixture.outlet("bottomView", as: UIView.self)
                let baseline = fixture.controller.orgHeight
                // Reserve the upper root area without changing the method list or its demand.
                fixture.controller.additionalSafeAreaInsets.top += max(0, view.bounds.height - view.safeAreaInsets.top - 180)
                view.setNeedsLayout()
                try await waitForDashboardLayout(fixture)
                XCTAssertEqual(fixture.controller.orgHeight, baseline, accuracy: 1,
                               "Restricted presentation space must not overwrite the dashboard's resting base")
                XCTAssertLessThanOrEqual(bottomView.bounds.height, max(0, view.bounds.height - view.safeAreaInsets.top) + 1)
                XCTAssertGreaterThan(tableView.contentSize.height + tableView.adjustedContentInset.top +
                                     tableView.adjustedContentInset.bottom, tableView.bounds.height + 1)
                XCTAssertTrue(tableView.isScrollEnabled)
                XCTAssertGreaterThan(tableView.bounds.height - tableView.adjustedContentInset.top -
                                     tableView.adjustedContentInset.bottom, 54)

                for (section, position) in [(2, UITableView.ScrollPosition.bottom), (0, .top)] {
                    let indexPath = IndexPath(row: 0, section: section)
                    tableView.scrollToRow(at: indexPath, at: position, animated: false)
                    tableView.layoutIfNeeded()
                    let row = tableView.rectForRow(at: indexPath)
                    let visibleTop = tableView.contentOffset.y + tableView.adjustedContentInset.top
                    let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
                    XCTAssertGreaterThanOrEqual(row.minY, visibleTop - 1,
                                               "Section \(section) must remain reachable in restricted height")
                    XCTAssertLessThanOrEqual(row.maxY, visibleBottom + 1,
                                            "Section \(section) must remain reachable in restricted height")
                }
            } catch {
                await fixture.stop()
                throw error
            }
            await fixture.stop()
        }
    }

    @MainActor
    func testCardFormRemovesEntireDocumentTailAndKeepsNativeBottomPadding() async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)])
        addTeardownBlock { await fixture.stop() }
        // Keep the regression meaningful on simulators without a home indicator.
        fixture.controller.additionalSafeAreaInsets.bottom = 12
        try await waitForPaymentMethods(fixture)
        let nativeHeight = fixture.controller.orgHeight
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)

        // Exercise both a fitted sheet and content taller than the available screen.
        for fieldHeight in [40, 260] {
            let previousHeight = fixture.controller.orgHeight
            webView.loadHTMLString("""
            <!doctype html><html><head><style>
                body { margin:0; padding:32px 0 96px; }
                .container { height:840px; padding-bottom:80px; }
                input { display:block; height:\(fieldHeight)px; box-sizing:border-box; }
                button { height:44px; }
                .form-group { height:200px; margin-bottom:36px; }
            </style></head><body>
                <div class="container"><form id="paymentForm">
                    <input id="cardHolderName"><input id="cardNo">
                    <input id="cardSecureId"><input id="cardExpiry">
                    <div class="form-group"><button id="payButton" class="btn-primary" type="submit">Pay</button></div>
                </form></div>
            </body></html>
            """, baseURL: nil)
            try await eventually {
                !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom < -20 &&
                    fixture.controller.orgHeight != previousHeight
            }

            let result: Any? = try await withCheckedThrowingContinuation { continuation in
                webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
            let layout = try XCTUnwrap(result as? [String: Double])
            let contentHeight = CGFloat(try XCTUnwrap(layout["height"]))
            let bottomSpacing = CGFloat(try XCTUnwrap(layout["bottomSpacing"]))
            let view = try XCTUnwrap(fixture.controller.view)
            view.layoutIfNeeded()
            let chromeHeight = try fixture.outlet("bottomView", as: UIView.self).bounds.height - webView.bounds.height
            let maximumHeight = view.bounds.height - view.safeAreaInsets.top
            let expectedHeight = min(contentHeight + chromeHeight + view.safeAreaInsets.bottom, maximumHeight)
            XCTAssertGreaterThan(bottomSpacing, 200)
            XCTAssertEqual(webView.scrollView.contentInset.bottom, -bottomSpacing, accuracy: 1)
            XCTAssertEqual(fixture.controller.orgHeight, expectedHeight, accuracy: 1)
            XCTAssertEqual(try fixture.outlet("height", as: NSLayoutConstraint.self).constant, expectedHeight, accuracy: 1)

            let keyboard = try keyboardNotification(for: fixture)
            fixture.controller.keyboardWillShowFunction(notification: keyboard)
            view.layoutIfNeeded()
            let keyboardOffset = try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant
            XCTAssertEqual(try fixture.outlet("height", as: NSLayoutConstraint.self).constant,
                           min(expectedHeight, maximumHeight - keyboardOffset), accuracy: 1)
            XCTAssertEqual(fixture.controller.orgHeight, expectedHeight, accuracy: 1)
            let expectedFocusedInset = -bottomSpacing + view.safeAreaInsets.bottom
            XCTAssertEqual(webView.scrollView.contentInset.bottom, expectedFocusedInset, accuracy: 1)

            fixture.controller.keyboardWillShowFunction(notification: keyboard)
            view.layoutIfNeeded()
            XCTAssertEqual(webView.scrollView.contentInset.bottom, expectedFocusedInset, accuracy: 1,
                           "Repeated keyboard notifications must not accumulate bottom padding")
            // WebKit publishes native scroll geometry after the DOM measurement callback.
            try await eventually {
                abs(webView.scrollView.contentSize.height - (contentHeight + bottomSpacing)) <= 1
            }
            webView.scrollView.contentOffset.y = webView.scrollView.contentSize.height + 1_000
            fixture.controller.scrollViewDidScroll(webView.scrollView)
            let bottomGap = webView.bounds.height - (contentHeight - webView.scrollView.contentOffset.y)
            XCTAssertEqual(bottomGap, view.safeAreaInsets.bottom, accuracy: 1,
                           "Scrolling to the final content must retain native padding above the keyboard")

            fixture.controller.keyboardWillHideFunction(notification: NSNotification(name: UIResponder.keyboardWillHideNotification, object: nil))
            XCTAssertEqual(webView.scrollView.contentInset.bottom, -bottomSpacing, accuracy: 1)
            XCTAssertEqual(try fixture.outlet("height", as: NSLayoutConstraint.self).constant, expectedHeight, accuracy: 1)
        }

        fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
        try assertNativeSheet(fixture, height: nativeHeight)
    }

    @MainActor
    func testFormSheetPreservesDashboardAndFallbackHeightInputs() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)

        XCTAssertTrue(fixture.controller.usesNativeSheet)
        XCTAssertEqual(fixture.controller.modalPresentationStyle, .formSheet)
        let sheet = try XCTUnwrap(fixture.controller.sheetPresentationController)
        XCTAssertEqual(sheet.detents.count, 1)
        XCTAssertFalse(sheet.prefersScrollingExpandsWhenScrolledToEdge)
        let dashboardHeight = (((fixture.sourceBounds.width - 20) / 5) - 15) * 3 + 195 + 20
        XCTAssertEqual(fixture.controller.orgHeight, dashboardHeight, accuracy: 0.5)
        XCTAssertLessThan(fixture.controller.view.bounds.height, fixture.sourceBounds.height,
                          "The production controller must be presented inside an actual resized sheet")

        let expectedWebHeight = min(fixture.sourceBounds.height * 0.48 + 64,
                                    fixture.sourceBounds.height - 20)
        XCTAssertEqual(fixture.controller.calculateWebHeight(), expectedWebHeight, accuracy: 0.5)
        let webHeight = try await enterWebPayment(fixture)
        XCTAssertEqual(webHeight, expectedWebHeight, accuracy: 0.5,
                       "Fallback sizing must keep its original presentation-container input")
        XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)
    }

    @MainActor
    func testFormSheetPreservesMeasuredHeightsAndUnknownRedirectHeight() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)

        for fieldHeight in [40, 400] {
            let previousHeight = fixture.controller.orgHeight
            webView.loadHTMLString(nativeCardFormHTML(fieldHeight: fieldHeight), baseURL: nil)
            try await eventually {
                !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom < -20 &&
                    fixture.controller.orgHeight != previousHeight
            }
            let result: Any? = try await withCheckedThrowingContinuation { continuation in
                webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
            let layout = try XCTUnwrap(result as? [String: Double])
            let contentHeight = CGFloat(try XCTUnwrap(layout["height"]))
            let bottomSpacing = CGFloat(try XCTUnwrap(layout["bottomSpacing"]))
            try await waitForNativeContentLayout(fixture)
            let bottomView = try fixture.outlet("bottomView", as: UIView.self)
            let chromeHeight = bottomView.bounds.height - webView.bounds.height
            let maximumHeight = fixture.sourceBounds.height - fixture.sourceSafeAreaInsets.top
            let expectedHeight = min(contentHeight + chromeHeight + fixture.sourceSafeAreaInsets.bottom,
                                     maximumHeight)
            XCTAssertEqual(fixture.controller.orgHeight, expectedHeight, accuracy: 1,
                           "UIKit's rendered height must not replace the resting form-height calculation")
            XCTAssertEqual(webView.scrollView.contentInset.bottom,
                           fixture.controller.view.safeAreaInsets.bottom - bottomSpacing, accuracy: 1)
            XCTAssertGreaterThan(bottomView.bounds.height, chromeHeight)
            XCTAssertLessThanOrEqual(bottomView.bounds.height, expectedHeight + 1)
            XCTAssertEqual(bottomView.bounds.height,
                           fixture.controller.view.bounds.height - fixture.controller.view.safeAreaInsets.top,
                           accuracy: 1)
            XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)
        }

        let retainedHeight = fixture.controller.orgHeight
        webView.loadHTMLString("<html><body><p>Bank authentication</p></body></html>", baseURL: nil)
        try await eventually {
            !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom == 0
        }
        // Drain WebKit's asynchronous measurement so this also checks the unknown-page result.
        _ = try await webView.evaluateJavaScript("document.body.textContent")
        XCTAssertEqual(fixture.controller.orgHeight, retainedHeight, accuracy: 1)
        XCTAssertEqual(webView.scrollView.contentInset.bottom, 0)
    }

    @MainActor
    func testFormSheetFitsLoadedFormWithoutResidualScrollTail() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        // A collapsed body margin is outside its border box, but remains scrollable.
        let html = nativeCardFormHTML(fieldHeight: 40)
            .replacingOccurrences(of: "margin:0;", with: "margin:8px;")
        webView.loadHTMLString(html, baseURL: nil)
        try await eventually {
            !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom < -20
        }
        try await waitForNativeContentLayout(fixture)
        let result = try await webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement)
        let layout = try XCTUnwrap(result as? [String: Double])
        let contentHeight = CGFloat(try XCTUnwrap(layout["height"]))
        let documentHeightResult = try await webView.evaluateJavaScript("document.scrollingElement.scrollHeight")
        let documentHeight = try XCTUnwrap(documentHeightResult as? Double)
        try await eventually { abs(webView.scrollView.contentSize.height - CGFloat(documentHeight)) <= 1 }
        let scrollView = webView.scrollView
        XCTAssertLessThanOrEqual(scrollView.contentSize.width, scrollView.bounds.width + 1)
        XCTAssertEqual(scrollView.contentSize.height + scrollView.contentInset.bottom,
                       contentHeight + fixture.controller.view.safeAreaInsets.bottom, accuracy: 1,
                       "The native inset must remove the entire document tail, including root margins")
        XCTAssertLessThanOrEqual(scrollView.contentSize.height + scrollView.adjustedContentInset.top +
                                 scrollView.adjustedContentInset.bottom - scrollView.bounds.height, 1,
                                 "A short fitted form must have no vertical travel: viewport \(scrollView.bounds), " +
                                 "content \(scrollView.contentSize), inset \(scrollView.adjustedContentInset), " +
                                 "root safe area \(fixture.controller.view.safeAreaInsets)")
        XCTAssertEqual(fixture.controller.orgHeight,
                       contentHeight + (try fixture.outlet("bottomView", as: UIView.self)).bounds.height -
                           webView.bounds.height + fixture.sourceSafeAreaInsets.bottom, accuracy: 1)
    }

    @MainActor
    func testRedirectContentExpandsAndRestoresPaymentBaselineInBothPresentations() async throws {
        for mode in redirectPresentationModes {
            try await withRedirectFixture(presentationMode: mode) { fixture, webView, baseline in
                let bottomView = try fixture.outlet("bottomView", as: UIView.self)
                let initialRenderedHeight = try await settledRenderedPanelHeight(in: fixture)
                let expectsAnimation = UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled
                var renderedHeights = [initialRenderedHeight]
                let renderingSampler = Task { @MainActor in
                    while !Task.isCancelled {
                        renderedHeights.append((bottomView.layer.presentation() ?? bottomView.layer).bounds.height)
                        try? await Task.sleep(nanoseconds: 10_000_000)
                    }
                }
                defer { renderingSampler.cancel() }
                webView.loadHTMLString(redirectPageHTML(title: "tall-challenge", buttonMargin: 700), baseURL: nil)
                XCTAssertEqual(fixture.controller.orgHeight, baseline, accuracy: 1,
                               "Starting a redirect must retain the current height until its content is measured")
                let tall = try await committedPageMeasurement(in: webView, title: "tall-challenge")
                XCTAssertEqual(tall["kind"] as? String, "page")
                let expandedHeight = try redirectHeight(tall, baseline: baseline, fixture: fixture)
                XCTAssertGreaterThan(expandedHeight, baseline)
                try await waitForRedirectHeight(expandedHeight, in: fixture)
                let finalRenderedHeight = try await settledRenderedPanelHeight(in: fixture)
                renderingSampler.cancel()
                await renderingSampler.value
                renderedHeights.append(finalRenderedHeight)
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(renderedHeights.min()), initialRenderedHeight - 1,
                                            "Starting the redirect must not briefly shrink the rendered panel")
                XCTAssertLessThanOrEqual(try XCTUnwrap(renderedHeights.max()), finalRenderedHeight + 1,
                                         "The rendered panel must not overshoot its settled content height")
                if expectsAnimation, finalRenderedHeight - initialRenderedHeight > 10 {
                    XCTAssertTrue(renderedHeights.contains {
                        $0 > initialRenderedHeight + 1 && $0 < finalRenderedHeight - 1
                    }, "The rendered panel must animate through an intermediate height: " +
                       "initial=\(initialRenderedHeight), final=\(finalRenderedHeight), samples=\(renderedHeights.count)")
                }

                for (title, html) in [
                    ("short-challenge", redirectPageHTML(title: "short-challenge", buttonMargin: 0)),
                    ("viewport-controls", """
                        <!doctype html><html><head><title>viewport-controls</title><style>
                            body { margin:0; height:100vh; display:flex; flex-direction:column;
                                   justify-content:space-between; font:14px/20px sans-serif; }
                            h1 { margin:0; font:inherit; }
                            button { display:block; height:44px; margin:0; padding:0; }
                        </style></head><body><h1>Bank authentication</h1><button>Continue</button></body></html>
                        """),
                    ("empty-viewport", "<!doctype html><html><head><title>empty-viewport</title></head><body style='margin:0;min-height:100vh'></body></html>")
                ] {
                    if abs(fixture.controller.orgHeight - baseline) <= 1 {
                        webView.loadHTMLString(redirectPageHTML(title: "expanded-again", buttonMargin: 700), baseURL: nil)
                        _ = try await committedPageMeasurement(in: webView, title: "expanded-again")
                        try await waitForRedirectHeight(expandedHeight, in: fixture)
                    }
                    let previousHeight = fixture.controller.orgHeight
                    webView.loadHTMLString(html, baseURL: nil)
                    XCTAssertEqual(fixture.controller.orgHeight, previousHeight, accuracy: 1)
                    let page = try await committedPageMeasurement(in: webView, title: title)
                    XCTAssertEqual(page["kind"] as? String, "page")
                    if title == "empty-viewport" {
                        XCTAssertEqual(try XCTUnwrap(page["height"] as? Double), 0, accuracy: 1,
                                       "An empty viewport-sized wrapper must not become intrinsic page content")
                    }
                    try await waitForRedirectHeight(baseline, in: fixture)
                    if title == "viewport-controls" {
                        let fittedPage = try await committedPageMeasurement(in: webView, title: title)
                        XCTAssertEqual(try XCTUnwrap(fittedPage["height"] as? Double),
                                       try XCTUnwrap(fittedPage["viewportHeight"] as? Double), accuracy: 1,
                                       "The trailing control must follow the viewport floor")
                        for _ in 0..<2 {
                            _ = try await webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'))")
                            // Observe the invariant across queued measurement turns,
                            // rather than checking only the synchronous event result.
                            let deadline = Date().addingTimeInterval(0.75)
                            var lowestHeight = baseline
                            var highestHeight = baseline
                            while Date() < deadline {
                                lowestHeight = min(lowestHeight, fixture.controller.orgHeight)
                                highestHeight = max(highestHeight, fixture.controller.orgHeight)
                                try await Task.sleep(nanoseconds: 20_000_000)
                            }
                            XCTAssertEqual(lowestHeight, baseline, accuracy: 1)
                            XCTAssertEqual(highestHeight, baseline, accuracy: 1,
                                           "Viewport-positioned controls must not grow the sheet on every resize notification")
                        }
                    }
                }

                webView.loadHTMLString(redirectCardFormHTML, baseURL: nil)
                let card = try await committedPageMeasurement(in: webView, title: "owned-card")
                XCTAssertEqual(card["kind"] as? String, "card")
                try await eventually { webView.scrollView.contentInset.bottom < -20 }
                try await waitForRedirectHeight(baseline, in: fixture)
                XCTAssertLessThan(webView.scrollView.contentInset.bottom, -20)
            }
        }
    }

    @MainActor
    func testRedirectObserverTracksLateContentGrowthAndShrinkInBothPresentations() async throws {
        for mode in redirectPresentationModes {
            try await withRedirectFixture(presentationMode: mode) { fixture, webView, baseline in
                webView.loadHTMLString(redirectPageHTML(title: "changing-challenge", buttonMargin: 180), baseURL: nil)
                let original = try await committedPageMeasurement(in: webView, title: "changing-challenge")
                let documentID = try XCTUnwrap(original["documentID"] as? String)
                let initialHeight = try redirectHeight(original, baseline: baseline, fixture: fixture)
                XCTAssertGreaterThan(initialHeight, baseline)
                try await waitForRedirectHeight(initialHeight, in: fixture)

                _ = try await webView.evaluateJavaScript("document.getElementById('challenge').style.marginTop = '700px'")
                let grown = try await committedPageMeasurement(in: webView, title: "changing-challenge")
                XCTAssertEqual(grown["documentID"] as? String, documentID)
                let expandedHeight = try redirectHeight(grown, baseline: baseline, fixture: fixture)
                XCTAssertGreaterThan(expandedHeight, baseline)
                try await waitForRedirectHeight(expandedHeight, in: fixture)

                _ = try await webView.evaluateJavaScript("document.getElementById('challenge').style.marginTop = '0px'")
                let shrunk = try await committedPageMeasurement(in: webView, title: "changing-challenge")
                XCTAssertEqual(shrunk["documentID"] as? String, documentID)
                XCTAssertLessThan(try XCTUnwrap(shrunk["height"] as? Double),
                                  try XCTUnwrap(grown["height"] as? Double))
                try await waitForRedirectHeight(baseline, in: fixture)

                // This small growth remains inside the resting viewport on devices
                // with bottom safe-area padding; document size alone need not change.
                _ = try await webView.evaluateJavaScript("document.getElementById('challenge').style.marginTop = '180px'")
                _ = try await committedPageMeasurement(in: webView, title: "changing-challenge")
                try await waitForRedirectHeight(initialHeight, in: fixture)
            }
        }
    }

    @MainActor
    func testRapidRedirectsAndOldDocumentSignalsPreserveCurrentPageSizing() async throws {
        for mode in redirectPresentationModes {
            try await withRedirectFixture(presentationMode: mode) { fixture, webView, baseline in
                webView.loadHTMLString(redirectPageHTML(title: "old-challenge", buttonMargin: 300), baseURL: nil)
                let oldPage = try await committedPageMeasurement(in: webView, title: "old-challenge")
                let oldDocumentID = try XCTUnwrap(oldPage["documentID"] as? String)
                let expandedHeight = try redirectHeight(oldPage, baseline: baseline, fixture: fixture)
                try await waitForRedirectHeight(expandedHeight, in: fixture)

                var minimumTransitionHeight = expandedHeight
                let transitionSampler = Task { @MainActor in
                    while !Task.isCancelled {
                        minimumTransitionHeight = min(minimumTransitionHeight, fixture.controller.orgHeight)
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }
                }
                defer { transitionSampler.cancel() }
                webView.loadHTMLString("<!doctype html><html><body></body></html>", baseURL: nil)
                XCTAssertEqual(fixture.controller.orgHeight, expandedHeight, accuracy: 1)
                webView.loadHTMLString(redirectPageHTML(title: "replacement-challenge", buttonMargin: 400), baseURL: nil)
                XCTAssertEqual(fixture.controller.orgHeight, expandedHeight, accuracy: 1,
                               "A rapid intermediate navigation must not reset the expanded sheet")
                let replacement = try await committedPageMeasurement(in: webView, title: "replacement-challenge")
                let replacementID = try XCTUnwrap(replacement["documentID"] as? String)
                XCTAssertNotEqual(replacementID, oldDocumentID)
                let replacementHeight = try redirectHeight(replacement, baseline: baseline, fixture: fixture)
                XCTAssertGreaterThan(replacementHeight, expandedHeight)
                try await waitForRedirectHeight(replacementHeight, in: fixture)
                transitionSampler.cancel()
                XCTAssertGreaterThanOrEqual(minimumTransitionHeight, expandedHeight - 1,
                                            "The intermediate empty document must not shrink the sheet during redirect replacement")

                let encodedID = try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: [oldDocumentID]),
                                                    encoding: .utf8))
                _ = try await webView.evaluateJavaScript("window.webkit.messageHandlers.payhereLayoutChanged.postMessage(\(encodedID)[0]); true")
                XCTAssertEqual(fixture.controller.orgHeight, replacementHeight, accuracy: 1)
                _ = try await webView.evaluateJavaScript("document.getElementById('challenge').style.marginTop = '0px'")
                let currentPage = try await committedPageMeasurement(in: webView, title: "replacement-challenge")
                XCTAssertEqual(currentPage["documentID"] as? String, replacementID)
                try await waitForRedirectHeight(baseline, in: fixture)
                _ = try await webView.evaluateJavaScript("document.getElementById('challenge').style.marginTop = '400px'")
                _ = try await committedPageMeasurement(in: webView, title: "replacement-challenge")
                try await waitForRedirectHeight(replacementHeight, in: fixture)
            }
        }
    }

    @MainActor
    func testFormSheetShortCurrentFormHasNoScrollTravel() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        webView.loadHTMLString(shortCurrentCardFormHTML, baseURL: nil)
        try await eventually {
            !webView.isLoading && !webView.isHidden &&
                webView.scrollView.contentInsetAdjustmentBehavior == .never
        }
        try await waitForNativeContentLayout(fixture)
        let geometry = try await committedShortCardFormGeometry(in: webView)
        let contentHeight = CGFloat(try XCTUnwrap(geometry["height"]))
        let bottomSpacing = try XCTUnwrap(geometry["bottomSpacing"])
        let payTop = CGFloat(try XCTUnwrap(geometry["payTop"]))
        let payBottom = CGFloat(try XCTUnwrap(geometry["payBottom"]))
        let scrollView = webView.scrollView
        let chromeHeight = (try fixture.outlet("bottomView", as: UIView.self)).bounds.height - webView.bounds.height

        XCTAssertEqual(bottomSpacing, 0, accuracy: 1, "The compact provider fixture must have no removable DOM tail")
        XCTAssertEqual(fixture.controller.orgHeight,
                       contentHeight + chromeHeight + fixture.sourceSafeAreaInsets.bottom, accuracy: 1)
        XCTAssertEqual(scrollView.contentSize.height, scrollView.bounds.height, accuracy: 1,
                       "WebKit's viewport floor must be exercised, without a larger trailing wrapper")
        XCTAssertLessThanOrEqual(scrollView.contentSize.height + scrollView.adjustedContentInset.top +
                                 scrollView.adjustedContentInset.bottom - scrollView.bounds.height, 1,
                                 "Bottom safe-area padding must not add scroll travel to a form that already fits")
        XCTAssertEqual(scrollView.contentOffset.y, 0, accuracy: 1)
        XCTAssertGreaterThanOrEqual(payTop - scrollView.contentOffset.y, 0)
        XCTAssertLessThanOrEqual(payBottom - scrollView.contentOffset.y, scrollView.bounds.height + 1)
        XCTAssertEqual(scrollView.bounds.height - (payBottom - scrollView.contentOffset.y),
                       fixture.sourceSafeAreaInsets.bottom, accuracy: 1,
                       "Removing excess travel must preserve the form's resting bottom padding")
    }
    
    @MainActor
    func testSyntheticKeyboardUsesLocalOverlapUnderScaledPresentationContent() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        try await waitForNativeContentLayout(fixture)
        let ancestor = UIView(frame: CGRect(x: 10, y: 10, width: 240, height: 280))
        ancestor.transform = CGAffineTransform(scaleX: 0.8, y: 0.75)
        let target = UIView(frame: CGRect(x: 10, y: 10, width: 200, height: 240))
        target.transform = CGAffineTransform(scaleX: 0.9, y: 0.85)
        ancestor.addSubview(target)
        fixture.controller.view.addSubview(ancestor)
        defer { ancestor.removeFromSuperview() }

        let notification = fixture.keyboardNotification(overlappingBottomOf: target, by: 120)
        let frame = try XCTUnwrap(
            notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue).cgRectValue
        let window = try XCTUnwrap(target.window)
        let intersection = target.bounds.intersection(target.convert(frame, from: window.screen.coordinateSpace))
        XCTAssertEqual(intersection.height, 120, accuracy: 0.001,
                       "Keyboard construction must convert the target's local overlap through every ancestor transform")
        XCTAssertEqual(intersection.maxY, target.bounds.maxY, accuracy: 0.001)
    }

    @MainActor
    func testFormSheetKeyboardPreservesRestingHeightAndScrollableBottomPadding() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)

        for fieldHeight in [40, 400] {
            let previousHeight = fixture.controller.orgHeight
            webView.loadHTMLString(nativeCardFormHTML(fieldHeight: fieldHeight), baseURL: nil)
            try await eventually {
                !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom < -20 &&
                    fixture.controller.orgHeight != previousHeight
            }
            let result = try await webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement)
            let layout = try XCTUnwrap(result as? [String: Double])
            let contentHeight = CGFloat(try XCTUnwrap(layout["height"]))
            let bottomSpacing = CGFloat(try XCTUnwrap(layout["bottomSpacing"]))
            try await eventually {
                abs(webView.scrollView.contentSize.height - contentHeight - bottomSpacing) <= 1
            }
            try await waitForNativeContentLayout(fixture)
            let restingHeight = fixture.controller.orgHeight
            let restingViewHeight = fixture.controller.view.bounds.height
            let bottomView = try fixture.outlet("bottomView", as: UIView.self)
            let restingPanelHeight = bottomView.bounds.height
            let chromeHeight = bottomView.bounds.height - webView.bounds.height
            let requestedOverlap = min(120, webView.bounds.height / 2)
            let keyboard = fixture.keyboardNotification(overlappingBottomOf: webView, by: requestedOverlap)
            let keyboardFrame = try XCTUnwrap(
                keyboard.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue).cgRectValue
            let window = try XCTUnwrap(webView.window)
            let keyboardInWebView = webView.convert(keyboardFrame, from: window.screen.coordinateSpace)
            let remainingOverlap = webView.bounds.intersection(keyboardInWebView).height
            XCTAssertEqual(remainingOverlap, requestedOverlap, accuracy: 1)

            // UIKit owns the outer sheet; the content panel must fit above its keyboard.
            fixture.controller.keyboardWillShowFunction(notification: keyboard)
            try await waitForNativeContentLayout(fixture, keyboardFrame: keyboardFrame)
            let expectedPanelHeight = expectedNativePanelHeight(fixture, keyboardFrame: keyboardFrame)
            let focusedIntersection = webView.bounds.intersection(
                webView.convert(keyboardFrame, from: window.screen.coordinateSpace))
            let focusedOverlap = focusedIntersection.isNull ? 0 : focusedIntersection.height
            XCTAssertEqual(focusedOverlap, 0, accuracy: 1)
            XCTAssertEqual(webView.bounds.height, max(0, expectedPanelHeight - chromeHeight), accuracy: 1)
            let expectedInset = fixture.sourceSafeAreaInsets.bottom - bottomSpacing
            XCTAssertEqual(webView.scrollView.contentInset.bottom, expectedInset, accuracy: 1)
            fixture.controller.keyboardWillShowFunction(notification: keyboard)
            try await waitForNativeContentLayout(fixture, keyboardFrame: keyboardFrame)
            XCTAssertEqual(webView.scrollView.contentInset.bottom, expectedInset, accuracy: 1,
                           "Repeated focus updates must not accumulate keyboard padding")
            XCTAssertEqual(fixture.controller.orgHeight, restingHeight, accuracy: 1)
            XCTAssertEqual(fixture.controller.view.bounds.height, restingViewHeight, accuracy: 1,
                           "The SDK must not resize the native sheet for keyboard occlusion")
            XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)

            webView.scrollView.contentOffset.y = webView.scrollView.contentSize.height + 1_000
            fixture.controller.scrollViewDidScroll(webView.scrollView)
            let visibleHeight = webView.bounds.height - focusedOverlap
            let bottomGap = visibleHeight - (contentHeight - webView.scrollView.contentOffset.y)
            XCTAssertEqual(bottomGap, fixture.sourceSafeAreaInsets.bottom, accuracy: 1,
                           "The final form content must retain its resting padding above the keyboard")

            fixture.controller.keyboardWillHideFunction(notification: NSNotification(
                name: UIResponder.keyboardWillHideNotification, object: nil))
            try await waitForNativeContentLayout(fixture)
            XCTAssertEqual(fixture.controller.orgHeight, restingHeight, accuracy: 1)
            XCTAssertEqual(bottomView.bounds.height, restingPanelHeight, accuracy: 1)
            XCTAssertEqual(webView.scrollView.contentInset.bottom,
                           fixture.controller.view.safeAreaInsets.bottom - bottomSpacing, accuracy: 1)
            XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)
        }
    }

    @MainActor
    func testFormSheetBackResultAndRetryRestoreDashboardHeight() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData),
                                                  "/pay/order_status": .success(Data("{\"status\":-2}".utf8))],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        let dashboardHeight = fixture.controller.orgHeight
        let firstWebHeight = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        let keyboard = fixture.keyboardNotification(overlappingBottomOf: webView, by: 120)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        fixture.controller.perform(NSSelectorFromString("backButtonClicked"))
        try assertNativeSheet(fixture, height: dashboardHeight)
        XCTAssertFalse(try fixture.outlet("tableView", as: UITableView.self).isHidden)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        fixture.controller.keyboardWillHideFunction(notification: NSNotification(
            name: UIResponder.keyboardWillHideNotification, object: nil))
        try assertNativeSheet(fixture, height: dashboardHeight)

        let secondWebHeight = try await enterWebPayment(fixture)
        XCTAssertEqual(secondWebHeight, firstWebHeight, accuracy: 0.5)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        try assertNativeSheet(fixture, height: dashboardHeight)
        fixture.controller.keyboardWillShowFunction(notification: keyboard)
        fixture.controller.keyboardWillHideFunction(notification: NSNotification(
            name: UIResponder.keyboardWillHideNotification, object: nil))
        try assertNativeSheet(fixture, height: dashboardHeight)
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        fixture.controller.perform(NSSelectorFromString("btnTryAgainTapped"))
        try await waitForPaymentMethods(fixture)
        try assertNativeSheet(fixture, height: dashboardHeight)
        XCTAssertEqual(fixture.delegate.callbackCount, 0)
        XCTAssertEqual(fixture.network.requestPaths.filter { $0 == "/pay/api/payment/v2/init" }.count, 2)
    }

    @MainActor
    func testFormSheetDismissalAttemptConfirmsAndResultCompletesOnce() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/order_status": .success(Data("{\"status\":2,\"paymentNo\":123}".utf8))],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        try await eventually { fixture.presentationIsSettled }
        let sheet = try XCTUnwrap(fixture.controller.sheetPresentationController)
        let presentationDelegate = try XCTUnwrap(sheet.delegate)
        XCTAssertEqual(presentationDelegate.presentationControllerShouldDismiss?(sheet), false)
        presentationDelegate.presentationControllerDidAttemptToDismiss?(sheet)
        try await eventually { fixture.alert != nil && fixture.presentationIsSettled }
        var alert: UIAlertController? = try XCTUnwrap(fixture.alert)
        presentationDelegate.presentationControllerDidAttemptToDismiss?(sheet)
        XCTAssertTrue(fixture.alert === alert)
        XCTAssertEqual(alert?.title, "Cancel Payment?")
        XCTAssertEqual(fixture.delegate.callbackCount, 0)

        await fixture.dismissAlert()
        alert = nil
        try await eventually { fixture.alert == nil && fixture.presentationIsSettled }

        fixture.controller.perform(NSSelectorFromString("orderStatusTimerTicked"))
        try await eventually {
            fixture.alert == nil && (try? fixture.outlet("viewPaymentSucess", as: UIView.self).isHidden) == false
        }
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnDoneTapped"))
        fixture.controller.perform(NSSelectorFromString("btnCancelTapped"))
        try await eventually { fixture.delegate.callbackCount == 1 }
        XCTAssertTrue(fixture.delegate.allCallbacksOnMainThread)
        XCTAssertTrue(fixture.delegate.resultArrivedAfterDismissal)
        XCTAssertEqual(fixture.delegate.response?.isSuccess(), true)
        XCTAssertEqual(fixture.delegate.errorCount, 0)
    }

    @MainActor
    func testFormSheetActualKeyboardKeepsRestingHeightAndFinalContentPadding() async throws {
        guard #available(iOS 16.0, *) else { throw XCTSkip("Custom sheet detents require iOS 16") }
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: .native)
        addTeardownBlock { await fixture.stop() }
        try await waitForPaymentMethods(fixture)
        _ = try await enterWebPayment(fixture)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        let previousHeight = fixture.controller.orgHeight
        webView.loadHTMLString(nativeCardFormHTML(fieldHeight: 80), baseURL: nil)
        try await eventually {
            !webView.isLoading && !webView.isHidden && webView.scrollView.contentInset.bottom < -20 &&
                fixture.controller.orgHeight != previousHeight && fixture.presentationIsSettled
        }
        let measurement = try await webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement)
        let layout = try XCTUnwrap(measurement as? [String: Double])
        let contentHeight = CGFloat(try XCTUnwrap(layout["height"]))
        let bottomSpacing = CGFloat(try XCTUnwrap(layout["bottomSpacing"]))
        try await waitForNativeContentLayout(fixture)
        let restingHeight = fixture.controller.orgHeight
        let bottomView = try fixture.outlet("bottomView", as: UIView.self)
        let restingPanelHeight = bottomView.bounds.height
        let chromeHeight = bottomView.bounds.height - webView.bounds.height
        let keyboard = PaymentKeyboardProbe()
        defer { keyboard.stop() }

        let focusedID = try await webView.callAsyncJavaScript("""
            document.getElementById('cardExpiry').focus();
            return document.activeElement.id;
            """, arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(focusedID as? String, "cardExpiry")
        let keyboardDeadline = Date().addingTimeInterval(5)
        while keyboard.visibleFrame == nil && Date() < keyboardDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard let keyboardFrame = keyboard.visibleFrame else {
            throw XCTSkip("Software keyboard did not appear after WKWebView focus; verify the simulator's software-keyboard configuration")
        }
        try await eventually {
            fixture.presentationIsSettled &&
                abs(webView.scrollView.contentSize.height - contentHeight - bottomSpacing) <= 1
        }
        try await waitForNativeContentLayout(fixture, keyboardFrame: keyboardFrame)
        let window = try XCTUnwrap(webView.window)
        let intersection = webView.bounds.intersection(
            webView.convert(keyboardFrame, from: window.screen.coordinateSpace))
        let overlap = !intersection.isNull && intersection.maxY >= webView.bounds.maxY
            ? intersection.height : 0
        let visibleHeight = webView.bounds.height - overlap
        let expectedVisibleHeight = max(0, expectedNativePanelHeight(fixture, keyboardFrame: keyboardFrame) - chromeHeight)
        XCTAssertGreaterThan(visibleHeight, 0)
        XCTAssertEqual(visibleHeight, expectedVisibleHeight, accuracy: 1,
                       "The content panel must preserve its resting height within native space above the keyboard")
        XCTAssertEqual(overlap, 0, accuracy: 1,
                       "The keyboard must not cover any part of the WebView viewport")
        let panelFrame = bottomView.convert(bottomView.bounds, to: fixture.controller.view)
        let keyboardInRoot = fixture.controller.view.convert(keyboardFrame, from: window.screen.coordinateSpace)
        XCTAssertLessThanOrEqual(panelFrame.maxY, keyboardInRoot.minY + 1)
        XCTAssertEqual(fixture.controller.orgHeight, restingHeight, accuracy: 1)
        XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)

        let secondFocusedID = try await webView.callAsyncJavaScript("""
            document.getElementById('cardSecureId').focus();
            return document.activeElement.id;
            """, arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(secondFocusedID as? String, "cardSecureId")
        let repeatedKeyboardFrame = try XCTUnwrap(keyboard.visibleFrame)
        try await waitForNativeContentLayout(fixture, keyboardFrame: repeatedKeyboardFrame)
        let repeatedIntersection = webView.bounds.intersection(
            webView.convert(repeatedKeyboardFrame, from: window.screen.coordinateSpace))
        let repeatedOverlap = !repeatedIntersection.isNull && repeatedIntersection.maxY >= webView.bounds.maxY
            ? repeatedIntersection.height : 0
        let repeatedVisibleHeight = webView.bounds.height - repeatedOverlap
        XCTAssertEqual(repeatedOverlap, 0, accuracy: 1)
        XCTAssertEqual(repeatedVisibleHeight, expectedVisibleHeight, accuracy: 1,
                       "Moving focus between fields must not expand the visible form")
        XCTAssertEqual(repeatedVisibleHeight, visibleHeight, accuracy: 1)
        XCTAssertEqual(fixture.controller.orgHeight, restingHeight, accuracy: 1)

        webView.scrollView.setContentOffset(CGPoint(x: 0, y: webView.scrollView.contentSize.height + 1_000),
                                            animated: false)
        fixture.controller.scrollViewDidScroll(webView.scrollView)
        let bottomGap = repeatedVisibleHeight - (contentHeight - webView.scrollView.contentOffset.y)
        XCTAssertEqual(bottomGap, fixture.sourceSafeAreaInsets.bottom, accuracy: 1,
                       "The final form content must retain padding above the actual software keyboard")

        webView.endEditing(true)
        try await eventually { keyboard.visibleFrame == nil && fixture.presentationIsSettled }
        try await waitForNativeContentLayout(fixture)
        XCTAssertEqual(fixture.controller.orgHeight, restingHeight, accuracy: 1)
        XCTAssertEqual(bottomView.bounds.height, restingPanelHeight, accuracy: 1)
        XCTAssertEqual(webView.scrollView.contentInset.bottom,
                       fixture.controller.view.safeAreaInsets.bottom - bottomSpacing, accuracy: 1)
    }

    private var redirectPresentationModes: [PaymentSheetPresentationMode] {
        if #available(iOS 16.0, *) { return [.native, .legacy] }
        return [.legacy]
    }

    private var redirectCardFormHTML: String {
        return nativeCardFormHTML(fieldHeight: 40)
            .replacingOccurrences(of: "<head>", with: "<head><title>owned-card</title>")
    }

    private func redirectPageHTML(title: String, buttonMargin: Int) -> String {
        return """
        <!doctype html><html><head><title>\(title)</title><style>
            body { margin:0; font:14px/20px sans-serif; }
            p { margin:0; }
            button { display:block; height:44px; margin:0; padding:0; box-sizing:border-box; }
        </style></head><body><p>Bank authentication</p>
            <button id="challenge" style="margin-top:\(buttonMargin)px">Continue authentication</button>
        </body></html>
        """
    }

    @MainActor
    private func withRedirectFixture(
        presentationMode: PaymentSheetPresentationMode,
        _ body: (PaymentControllerFixture, WKWebView, CGFloat) async throws -> Void
    ) async throws {
        let fixture = try makeFixture(configuration: .default, api: .CheckOut,
                                      responses: ["/pay/api/payment/v2/init": .success(initializationData),
                                                  "/pay/api/payment/submit": .success(webSubmissionData)],
                                      presentationMode: presentationMode)
        do {
            try await waitForPaymentMethods(fixture)
            _ = try await enterWebPayment(fixture)
            let webView = try fixture.outlet("webView", as: WKWebView.self)
            webView.loadHTMLString(redirectCardFormHTML, baseURL: nil)
            let card = try await committedPageMeasurement(in: webView, title: "owned-card")
            XCTAssertEqual(card["kind"] as? String, "card")
            let baseline = try redirectHeight(card, baseline: 0, fixture: fixture)
            try await waitForRedirectHeight(baseline, in: fixture)
            if fixture.controller.usesNativeSheet {
                XCTAssertEqual(webView.scrollView.contentInsetAdjustmentBehavior, .never)
            }
            try await body(fixture, webView, baseline)
        } catch {
            await fixture.stop()
            throw error
        }
        await fixture.stop()
    }

    @MainActor
    private func redirectHeight(_ measurement: [String: Any], baseline: CGFloat,
                                fixture: PaymentControllerFixture) throws -> CGFloat {
        let contentHeight = CGFloat(try XCTUnwrap(measurement["height"] as? Double))
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        let chromeHeight = (try fixture.outlet("bottomView", as: UIView.self)).bounds.height - webView.bounds.height
        return min(max(baseline, contentHeight + chromeHeight + fixture.sourceSafeAreaInsets.bottom),
                   fixture.sourceBounds.height - fixture.sourceSafeAreaInsets.top)
    }

    @MainActor
    private func committedPageMeasurement(in webView: WKWebView, title: String) async throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(5)
        var previousDocumentID: String?
        var previousGeometry: [Double] = []
        var lastGeometry: [Double] = []
        var stableSince: Date?
        var stableSamples = 0
        var titleMatches = false
        var lastEvaluationErrorCode = 0
        while Date() < deadline {
            guard !webView.isLoading, !webView.isHidden else {
                previousDocumentID = nil
                stableSince = nil
                stableSamples = 0
                try await Task.sleep(nanoseconds: 20_000_000)
                continue
            }
            do {
                let result = try await webView.evaluateJavaScript("""
                    (() => {
                        const result = \(PHWebViewScripts.pageMeasurement)
                        result.fixtureTitle = document.title;
                        return result;
                    })();
                    """)
                let measurement = result as? [String: Any]
                titleMatches = measurement?["fixtureTitle"] as? String == title
                if let measurement = measurement,
                   let documentID = measurement["documentID"] as? String, !documentID.isEmpty,
                   let viewportWidth = measurement["viewportWidth"] as? Double,
                   let viewportHeight = measurement["viewportHeight"] as? Double,
                   let documentHeight = measurement["documentHeight"] as? Double,
                   let contentHeight = measurement["height"] as? Double,
                   let bottomSpacing = measurement["bottomSpacing"] as? Double {
                    let scrollView = webView.scrollView
                    let inset = scrollView.adjustedContentInset
                    let geometry = [viewportWidth, viewportHeight, documentHeight, contentHeight, bottomSpacing,
                                    Double(webView.bounds.width), Double(webView.bounds.height),
                                    Double(scrollView.bounds.width), Double(scrollView.bounds.height),
                                    Double(scrollView.contentSize.width), Double(scrollView.contentSize.height),
                                    Double(inset.top), Double(inset.bottom), Double(inset.left), Double(inset.right)]
                    lastGeometry = geometry
                    // Automatic safe-area adjustment can make DOM and native heights
                    // differ. Require each geometry to settle, without equating them.
                    if titleMatches, !webView.isLoading, !webView.isHidden,
                       geometry.allSatisfy({ $0.isFinite }), viewportWidth > 0, viewportHeight > 0,
                       abs(viewportWidth - Double(webView.bounds.width)) <= 1 {
                        if documentID == previousDocumentID, geometry == previousGeometry {
                            stableSamples += 1
                            if stableSamples >= 2, let stableSince = stableSince,
                               Date().timeIntervalSince(stableSince) >= 0.1 {
                                return measurement
                            }
                        } else {
                            stableSince = Date()
                            stableSamples = 1
                        }
                        previousDocumentID = documentID
                        previousGeometry = geometry
                    } else {
                        previousDocumentID = nil
                        stableSince = nil
                        stableSamples = 0
                    }
                } else {
                    previousDocumentID = nil
                    stableSince = nil
                    stableSamples = 0
                }
            } catch {
                // A document replacement can invalidate an evaluation after the
                // preflight check. Retry against the finished target document.
                lastEvaluationErrorCode = (error as NSError).code
                previousDocumentID = nil
                stableSince = nil
                stableSamples = 0
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Redirect geometry did not settle: loading=\(webView.isLoading ? 1 : 0), " +
                "hidden=\(webView.isHidden ? 1 : 0), titleMatches=\(titleMatches ? 1 : 0), " +
                "samples=\(stableSamples), evaluationError=\(lastEvaluationErrorCode), " +
                "DOM[w,h,document,content,tail], native[webW,webH,scrollW,scrollH,contentW,contentH,insetT,insetB,insetL,insetR]=\(lastGeometry)")
        throw URLError(.timedOut)
    }

    @MainActor
    private func waitForRedirectHeight(_ expectedHeight: CGFloat, in fixture: PaymentControllerFixture) async throws {
        try await eventually { abs(fixture.controller.orgHeight - expectedHeight) <= 1 }
        if fixture.controller.usesNativeSheet {
            try await waitForNativeContentLayout(fixture)
            XCTAssertEqual(fixture.controller.orgHeight, expectedHeight, accuracy: 1)
            return
        }
        let bottomView = try fixture.outlet("bottomView", as: UIView.self)
        var previousBounds: CGRect?
        var stableSince = Date()
        try await eventually {
            fixture.controller.view.layoutIfNeeded()
            let presentedBounds = bottomView.layer.presentation()?.bounds ?? bottomView.bounds
            guard fixture.presentationIsSettled,
                  abs(bottomView.bounds.height - expectedHeight) <= 1,
                  abs(presentedBounds.height - expectedHeight) <= 1,
                  presentedBounds == previousBounds else {
                previousBounds = presentedBounds
                stableSince = Date()
                return false
            }
            return Date().timeIntervalSince(stableSince) >= 0.1
        }
    }

    @MainActor
    private func settledRenderedPanelHeight(in fixture: PaymentControllerFixture) async throws -> CGFloat {
        let bottomView = try fixture.outlet("bottomView", as: UIView.self)
        var previousHeight: CGFloat?
        var stableSince = Date()
        try await eventually {
            let renderedHeight = (bottomView.layer.presentation() ?? bottomView.layer).bounds.height
            guard fixture.presentationIsSettled,
                  abs(renderedHeight - bottomView.bounds.height) <= 1,
                  renderedHeight == previousHeight else {
                previousHeight = renderedHeight
                stableSince = Date()
                return false
            }
            return Date().timeIntervalSince(stableSince) >= 0.1
        }
        return (bottomView.layer.presentation() ?? bottomView.layer).bounds.height
    }

    private var shortCurrentCardFormHTML: String {
        return """
        <!doctype html><html><head><style>
            body { margin:0; font:14px/20px sans-serif; }
            .container { height:840px; }
            form, label, input, select, button { margin:0; padding:0; }
            label { display:block; }
            input, select { display:block; width:100%; height:32px; box-sizing:border-box; }
            .expiry { display:flex; }
            .expiry select { width:50%; }
            button { display:block; width:100%; height:44px; box-sizing:border-box; }
        </style></head><body>
            <div class="container"><form id="paymentForm">
                <label for="cardholder-name">Cardholder name</label><input id="cardholder-name">
                <label for="card-number">Card number</label><input id="card-number" inputmode="numeric">
                <label for="cardSecureId">Security code</label><input id="cardSecureId" inputmode="numeric">
                <label for="expiry-month">Expiry date</label><div class="expiry">
                    <select id="expiry-month"><option>01</option></select>
                    <select id="expiry-year"><option>2030</option></select>
                </div>
                <button id="payButton" class="btn-primary" type="submit">Pay</button>
            </form></div>
        </body></html>
        """
    }

    @MainActor
    private func committedShortCardFormGeometry(in webView: WKWebView) async throws -> [String: Double] {
        let deadline = Date().addingTimeInterval(5)
        var stableSince: Date?
        var previousGeometry: [String: Double]?
        while Date() < deadline {
            let result = try await webView.evaluateJavaScript("""
                (() => {
                    const measured = \(PHWebViewScripts.cardFormMeasurement);
                    const button = document.getElementById('payButton').getBoundingClientRect();
                    return Object.assign({}, measured, {
                        viewportHeight:window.innerHeight,
                        documentHeight:document.scrollingElement.scrollHeight,
                        payTop:button.top + window.scrollY, payBottom:button.bottom + window.scrollY
                    });
                })();
                """)
            var geometry = try XCTUnwrap(result as? [String: Double])
            let viewportHeight = CGFloat(try XCTUnwrap(geometry["viewportHeight"]))
            let documentHeight = CGFloat(try XCTUnwrap(geometry["documentHeight"]))
            let scrollView = webView.scrollView
            geometry["nativeViewportHeight"] = Double(scrollView.bounds.height)
            geometry["nativeContentHeight"] = Double(scrollView.contentSize.height)
            geometry["contentInsetTop"] = Double(scrollView.contentInset.top)
            geometry["contentInsetBottom"] = Double(scrollView.contentInset.bottom)
            geometry["adjustedInsetTop"] = Double(scrollView.adjustedContentInset.top)
            geometry["adjustedInsetBottom"] = Double(scrollView.adjustedContentInset.bottom)
            geometry["contentOffsetY"] = Double(scrollView.contentOffset.y)
            geometry["presentedContentOffsetY"] = Double((scrollView.layer.presentation() ?? scrollView.layer).bounds.minY)
            geometry["safeAreaBottom"] = Double(webView.safeAreaInsets.bottom)
            geometry["zoomScale"] = Double(scrollView.zoomScale)
            // Keyboard motion can outlive the controller's transition coordinator.
            // Include the presentation tree as well as the committed DOM metrics.
            var ancestor: UIView? = webView
            var index = 0
            while let current = ancestor {
                let layer = current.layer.presentation() ?? current.layer
                geometry["layer\(index)PositionY"] = Double(layer.position.y)
                geometry["layer\(index)Height"] = Double(layer.bounds.height)
                geometry["layer\(index)ScaleX"] = Double(layer.transform.m11)
                geometry["layer\(index)ScaleY"] = Double(layer.transform.m22)
                ancestor = current.superview
                index += 1
            }
            if geometry == previousGeometry,
               abs(webView.bounds.height - viewportHeight) <= 1,
               abs(webView.scrollView.contentSize.height - documentHeight) <= 1 {
                if let stableSince = stableSince, Date().timeIntervalSince(stableSince) >= 0.1 { return geometry }
                if stableSince == nil { stableSince = Date() }
            } else {
                stableSince = nil
            }
            previousGeometry = geometry
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Compact form geometry did not settle: \(previousGeometry ?? [:])")
        throw URLError(.timedOut)
    }

    private func nativeCardFormHTML(fieldHeight: Int) -> String {
        return """
        <!doctype html><html><head><style>
            body { margin:0; padding:32px 0 96px; }
            .container { padding-bottom:80px; }
            input { display:block; height:\(fieldHeight)px; box-sizing:border-box; }
            button { height:44px; }
            .form-group { height:200px; margin-bottom:36px; }
        </style></head><body>
            <div class="container"><form id="paymentForm">
                <input id="cardHolderName"><input id="cardNo">
                <input id="cardSecureId"><input id="cardExpiry">
                <div class="form-group"><button id="payButton" class="btn-primary" type="submit">Pay</button></div>
            </form></div>
        </body></html>
        """
    }

    @MainActor
    private func waitForNativeContentLayout(_ fixture: PaymentControllerFixture) async throws {
        try await waitForNativeContentLayout(fixture, keyboardFrame: nil)
    }

    @MainActor
    private func expectedNativePanelHeight(_ fixture: PaymentControllerFixture, keyboardFrame: CGRect?) -> CGFloat {
        let view = fixture.controller.view!
        let overlap: CGFloat
        if let keyboardFrame = keyboardFrame, let window = view.window {
            let intersection = view.bounds.intersection(
                view.convert(keyboardFrame, from: window.screen.coordinateSpace))
            overlap = !intersection.isNull && intersection.maxY >= view.bounds.maxY ? intersection.height : 0
        } else {
            overlap = 0
        }
        return min(fixture.controller.orgHeight, max(0, view.bounds.height - view.safeAreaInsets.top - overlap))
    }

    @MainActor
    private func waitForNativeContentLayout(_ fixture: PaymentControllerFixture, keyboardFrame: CGRect?) async throws {
        let view = try XCTUnwrap(fixture.controller.view)
        let bottomView = try fixture.outlet("bottomView", as: UIView.self)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        var previousGeometry: [CGFloat] = []
        var stableSince = Date()
        try await eventually {
            view.layoutIfNeeded()
            let geometry = [view.frame.minY, view.bounds.width, view.bounds.height,
                            view.safeAreaInsets.top, view.safeAreaInsets.bottom,
                            bottomView.bounds.height, webView.bounds.height]
            guard fixture.presentationIsSettled,
                  abs(bottomView.bounds.height - expectedNativePanelHeight(fixture, keyboardFrame: keyboardFrame)) <= 1,
                  geometry == previousGeometry else {
                previousGeometry = geometry
                stableSince = Date()
                return false
            }
            return Date().timeIntervalSince(stableSince) >= 0.1
        }
    }

    @MainActor
    private func enterWebPayment(_ fixture: PaymentControllerFixture) async throws -> CGFloat {
        let method = try JSONDecoder().decode(PaymentMethod.self, from: Data("{\"method\":\"VISA\",\"submissionCode\":\"VISA\"}".utf8))
        fixture.controller.didSelectedPaymentOption(paymentMethod: method, selectedSection: 1)
        let webView = try fixture.outlet("webView", as: WKWebView.self)
        try await eventually { !webView.isHidden && webView.url?.absoluteString == "about:blank" }
        return fixture.controller.orgHeight
    }

    @MainActor
    private func keyboardNotification(for fixture: PaymentControllerFixture) throws -> NSNotification {
        let view = try XCTUnwrap(fixture.controller.view)
        let window = try XCTUnwrap(view.window)
        let frame = CGRect(x: 0, y: view.bounds.maxY - 220, width: view.bounds.width, height: 220)
        let screenFrame = view.convert(frame, to: window.screen.coordinateSpace)
        return NSNotification(name: UIResponder.keyboardWillShowNotification, object: nil,
                              userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: screenFrame)])
    }

    @MainActor
    private func assertNativeSheet(_ fixture: PaymentControllerFixture, height: CGFloat) throws {
        XCTAssertEqual(fixture.controller.orgHeight, height, accuracy: 0.5)
        XCTAssertEqual(try fixture.outlet("height", as: NSLayoutConstraint.self).constant, height, accuracy: 0.5)
        XCTAssertEqual(try fixture.outlet("bottomConstraint", as: NSLayoutConstraint.self).constant, 0)
        XCTAssertEqual(try fixture.outlet("webView", as: WKWebView.self).scrollView.contentInset.bottom, 0)
        XCTAssertTrue(try fixture.outlet("webView", as: WKWebView.self).isHidden)
    }

    private var webSubmissionData: Data {
        return Data("{\"status\":1,\"data\":{\"url\":\"about:blank\"}}".utf8)
    }

    private var dashboardInitializationData: Data {
        return Data("""
        {"status":1,"data":{"order":{"orderKey":"test-order"},"paymentMethods":[
            {"method":"HELAPAY","orderNo":0,"submissionCode":"HELAPAY"},
            {"method":"VISA","orderNo":1,"submissionCode":"VISA","view":{"windowSize":{"width":390,"height":400}}},
            {"method":"MASTER","orderNo":2,"submissionCode":"MASTER","view":{"windowSize":{"width":390,"height":320}}},
            {"method":"FRIMI","orderNo":3,"submissionCode":"FRIMI"},
            {"method":"QPLUS","orderNo":4,"submissionCode":"QPLUS"},
            {"method":"IPAY","orderNo":5,"submissionCode":"IPAY"}
        ]}}
        """.utf8)
    }

    private var initializationData: Data {
        return Data("{\"status\":1,\"data\":{\"order\":{\"orderKey\":\"test-order\"},\"paymentMethods\":[{\"method\":\"VISA\",\"orderNo\":1,\"submissionCode\":\"VISA\"}]}}".utf8)
    }

    @MainActor
    private func waitForDashboardLayout(_ fixture: PaymentControllerFixture) async throws {
        let view = try XCTUnwrap(fixture.controller.view)
        let tableView = try fixture.outlet("tableView", as: UITableView.self)
        let bottomView = try fixture.outlet("bottomView", as: UIView.self)
        var previousGeometry: [CGFloat] = []
        var stableSince = Date()
        try await eventually {
            view.layoutIfNeeded()
            tableView.layoutIfNeeded()
            let geometry = [fixture.controller.orgHeight, view.bounds.height, view.safeAreaInsets.top,
                            view.safeAreaInsets.bottom, bottomView.bounds.height, tableView.bounds.height,
                            tableView.contentSize.height, tableView.adjustedContentInset.top,
                            tableView.adjustedContentInset.bottom]
            guard !tableView.isHidden, fixture.presentationIsSettled,
                  tableView.contentSize.height > 0, geometry == previousGeometry else {
                previousGeometry = geometry
                stableSince = Date()
                return false
            }
            return Date().timeIntervalSince(stableSince) >= 0.15
        }
    }

    @MainActor
    private func waitForPaymentMethods(_ fixture: PaymentControllerFixture) async throws {
        try await eventually {
            fixture.network.requestPaths.contains("/pay/api/payment/v2/init") &&
                (try? fixture.outlet("tableView", as: UITableView.self).isHidden) == false &&
                (try? fixture.outlet("progressBar", as: UIActivityIndicatorView.self).isHidden) == true
        }
    }

    @MainActor
    private func makeFixture(configuration: PHPaymentConfiguration, api: SelectedAPI,
                             responses: [String: Result<Data, Error>]) throws -> PaymentControllerFixture {
        return try makeFixture(configuration: configuration, api: api, responses: responses,
                               presentationMode: .legacy)
    }

    @MainActor
    private func makeFixture(configuration: PHPaymentConfiguration, api: SelectedAPI,
                             responses: [String: Result<Data, Error>],
                             presentationMode: PaymentSheetPresentationMode) throws -> PaymentControllerFixture {
        // Logic-only package runners have no application event loop for presentation.
        guard let application = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication,
              application.delegate != nil else {
            throw XCTSkip("UI integration tests require the demoapp host. Run the PayHereSDK-Tests scheme in Demo/Demo.xcodeproj.")
        }
        let scene = try XCTUnwrap(application.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "The demoapp test host must connect its window scene before UI tests start")
        return try PaymentControllerFixture(configuration: configuration, api: api,
                                             responses: responses, windowScene: scene,
                                             presentationMode: presentationMode)
    }

    @MainActor
    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Expected controller state was not reached", file: file, line: line)
                throw URLError(.timedOut)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

private enum PaymentSheetPresentationMode {
    case legacy
    case native
}

@MainActor
private final class PaymentKeyboardProbe: NSObject {
    private(set) var visibleFrame: CGRect?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(didShowKeyboard(_:)),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didHideKeyboard(_:)),
                                               name: UIResponder.keyboardDidHideNotification, object: nil)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didShowKeyboard(_ notification: Notification) {
        visibleFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    }

    @objc private func didHideKeyboard(_ notification: Notification) {
        visibleFrame = nil
    }
}

@MainActor
private final class PaymentControllerFixture {
    let controller: PHBottomViewController
    let delegate: RecordingPaymentDelegate
    let network: PaymentNetworkStub
    let sourceBounds: CGRect
    let sourceSafeAreaInsets: UIEdgeInsets
    private let window: UIWindow
    private let presenter: UIViewController
    private let previousBaseURL: String?

    var alert: UIAlertController? { controller.presentedViewController as? UIAlertController }

    var presentationIsSettled: Bool {
        var presented: UIViewController? = presenter
        while let current = presented {
            if current.isBeingPresented || current.isBeingDismissed || current.transitionCoordinator != nil {
                return false
            }
            presented = current.presentedViewController
        }
        return true
    }

    init(configuration: PHPaymentConfiguration, api: SelectedAPI,
         responses: [String: Result<Data, Error>], windowScene: UIWindowScene,
         presentationMode: PaymentSheetPresentationMode) throws {
        previousBaseURL = PHConfigs.BASE_URL
        network = PaymentNetworkStub(responses: responses)
        let presentationController = UIViewController()
        presenter = presentationController
        delegate = RecordingPaymentDelegate(isDismissed: { [weak presentationController] in presentationController?.presentedViewController == nil })
        let storyboard = UIStoryboard(name: "PayHere", bundle: Bundle.payHereBundle)
        controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "PHBottomViewController") as? PHBottomViewController)
        let request = PHInitialRequest(merchantID: "1210000", notifyURL: nil, firstName: "Test",
                                       lastName: "Customer", email: "test@example.invalid", phone: nil,
                                       address: nil, city: nil, country: nil, orderID: "test-order",
                                       itemsDescription: "Test", itemsMap: nil, currency: .LKR, amount: 10,
                                       deliveryAddress: nil, deliveryCity: nil, deliveryCountry: nil,
                                       custom1: nil, custom2: nil)
        request.api = api
        controller.initialRequest = request
        controller.isSandBoxEnabled = true
        controller.configuration = configuration
        controller.delegate = delegate
        controller.networkSession = network.makeSession()
        window = UIWindow(windowScene: windowScene)
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        presenter.view.layoutIfNeeded()
        sourceBounds = presenter.view.bounds
        sourceSafeAreaInsets = presenter.view.safeAreaInsets
        switch presentationMode {
        case .legacy:
            controller.modalPresentationStyle = .overFullScreen
        case .native:
            controller.configurePresentation(from: presenter)
        }
        presenter.present(controller, animated: false)
    }

    func outlet<T>(_ name: String, as type: T.Type) throws -> T {
        return try XCTUnwrap(controller.value(forKey: name) as? T)
    }

    func keyboardNotification(overlappingBottomOf targetView: UIView, by overlap: CGFloat) -> NSNotification {
        let coordinateSpace = window.screen.coordinateSpace
        let windowFrame = window.convert(window.bounds, to: coordinateSpace)
        let sourceFrame = presenter.view.convert(presenter.view.bounds, to: coordinateSpace)
        let targetTop = CGPoint(x: targetView.bounds.midX, y: targetView.bounds.maxY - overlap)
        let keyboardTop = targetView.convert(targetTop, to: coordinateSpace).y
        let keyboardBottom = max(coordinateSpace.bounds.maxY, max(windowFrame.maxY, sourceFrame.maxY))
        let keyboardFrame = CGRect(x: coordinateSpace.bounds.minX, y: keyboardTop,
                                   width: coordinateSpace.bounds.width, height: keyboardBottom - keyboardTop)
        let sourceIntersection = presenter.view.bounds.intersection(
            presenter.view.convert(keyboardFrame, from: coordinateSpace))
        XCTAssertFalse(sourceIntersection.isNull)
        XCTAssertGreaterThan(sourceIntersection.height, 0)
        XCTAssertGreaterThanOrEqual(sourceIntersection.maxY, presenter.view.bounds.maxY,
                                   "A docked keyboard must reach the presentation source's bottom edge")
        return NSNotification(name: UIResponder.keyboardWillShowNotification, object: nil,
                              userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame)])
    }

    func dismissAlert() async {
        guard let alert = alert else { return }
        await withCheckedContinuation { continuation in
            alert.dismiss(animated: false) { continuation.resume() }
        }
    }

    private func waitForPresentationToSettle() async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while !presentationIsSettled && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return presentationIsSettled
    }

    func stop() async {
        defer {
            network.unregister()
            PHConfigs.BASE_URL = previousBaseURL
        }
        guard await waitForPresentationToSettle() else {
            XCTFail("Payment presentation did not settle before fixture cleanup")
            return
        }
        await dismissAlert()
        guard await waitForPresentationToSettle() else {
            XCTFail("Cancellation alert did not settle before fixture cleanup")
            return
        }
        controller.perform(NSSelectorFromString("btnCancelTapped"))
        // Let the controller cancel its timers and finish any in-progress dismissal.
        let deadline = Date().addingTimeInterval(2)
        while presenter.presentedViewController != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard await waitForPresentationToSettle() else {
            XCTFail("Payment dismissal did not settle before fixture cleanup")
            return
        }
        if presenter.presentedViewController != nil {
            await withCheckedContinuation { continuation in
                presenter.dismiss(animated: false) { continuation.resume() }
            }
        }
        window.isHidden = true
        window.rootViewController = nil
        controller.networkSession.cancelAllRequests()
    }
}

private final class RecordingPaymentDelegate: PayHereSDKDelegate {
    private let lock = NSLock()
    private let isDismissed: () -> Bool
    private var receivedResponse: PHResponse<Any>?
    private var receivedError: PHPaymentError?
    private var responses = 0
    private var errors = 0
    private var callbacksOnMainThread = true
    private var dismissedBeforeResult = false

    init(isDismissed: @escaping () -> Bool) { self.isDismissed = isDismissed }
    var callbackCount: Int { locked { responses + errors } }
    var errorCount: Int { locked { errors } }
    var response: PHResponse<Any>? { locked { receivedResponse } }
    var error: PHPaymentError? { locked { receivedError } }
    var allCallbacksOnMainThread: Bool { locked { callbacksOnMainThread } }
    var resultArrivedAfterDismissal: Bool { locked { dismissedBeforeResult } }

    func payHereSDK(didReceive response: PHResponse<Any>) {
        let onMain = Thread.isMainThread
        let dismissed = onMain && isDismissed()
        locked {
            receivedResponse = response
            responses += 1
            callbacksOnMainThread = callbacksOnMainThread && onMain
            dismissedBeforeResult = dismissed
        }
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        let onMain = Thread.isMainThread
        let dismissed = onMain && isDismissed()
        locked {
            receivedError = error
            errors += 1
            callbacksOnMainThread = callbacksOnMainThread && onMain
            dismissedBeforeResult = dismissed
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class TypedControllerErrorDelegate: PayHereSDKDelegate {
    private let lock = NSLock()
    private weak var controller: PHBottomViewController?
    private var receivedError: PHPaymentError?
    private var errors = 0
    private var responses = 0
    private var callbacksOnMainThread = true
    private var dismissedBeforeError = false

    init(controller: PHBottomViewController) { self.controller = controller }
    var error: PHPaymentError? { locked { receivedError } }
    var errorCount: Int { locked { errors } }
    var responseCount: Int { locked { responses } }
    var allCallbacksOnMainThread: Bool { locked { callbacksOnMainThread } }
    var errorArrivedAfterDismissal: Bool { locked { dismissedBeforeError } }

    func payHereSDK(didReceive response: PHResponse<Any>) {
        locked { responses += 1 }
        XCTFail("An error must not also produce a payment result")
    }

    func payHereSDK(didFailWith error: PHPaymentError) {
        let onMain = Thread.isMainThread
        let dismissed = onMain && controller?.presentingViewController == nil
        locked {
            receivedError = error
            errors += 1
            callbacksOnMainThread = callbacksOnMainThread && onMain
            dismissedBeforeError = dismissed
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

// Exercises the completed downward swipe through the controller's gesture handler.
@MainActor
private final class ClosingPaymentPanGesture: UIPanGestureRecognizer {
    override var state: UIGestureRecognizer.State {
        get { .ended }
        set {}
    }
    override func translation(in view: UIView?) -> CGPoint { .zero }
    override func velocity(in view: UIView?) -> CGPoint { CGPoint(x: 0, y: 1_500) }
}

// Records page loads without issuing real web requests.
@MainActor
private final class RecordingPaymentWebView: WKWebView {
    private(set) var requests: [URLRequest] = []
    private(set) var navigations: [WKNavigation] = []
    private let navigationFactory = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func load(_ request: URLRequest) -> WKNavigation? {
        requests.append(request)
        // WebKit must initialize its native navigation backing, including for deallocation.
        // Keep its real loading callbacks isolated from the controller under test.
        guard let navigation = navigationFactory.loadHTMLString("<html></html>", baseURL: nil) else { return nil }
        navigations.append(navigation)
        return navigation
    }
}

// Exercises completion-URL policy handling without loading a remote payment page.
private final class PaymentCompletionNavigationAction: WKNavigationAction {
    private let completionRequest: URLRequest

    init(url: URL) {
        var request = URLRequest(url: url)
        request.mainDocumentURL = url
        completionRequest = request
        super.init()
    }

    override var request: URLRequest { completionRequest }
}

private final class PaymentNetworkStub {
    let identifier = UUID().uuidString
    private let lock = NSLock()
    private let responses: [String: Result<Data, Error>]
    private var requests: [URLRequest] = []

    init(responses: [String: Result<Data, Error>]) { self.responses = responses }

    var requestPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests.compactMap { $0.url?.path }
    }

    func makeSession() -> Alamofire.Session {
        PaymentURLProtocol.register(self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PaymentURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-PayHere-Test-ID": identifier]
        return Alamofire.Session(configuration: configuration)
    }

    func respond(to request: URLRequest) -> Result<Data, Error> {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        guard let response = responses[request.url?.path ?? ""] else {
            XCTFail("Unexpected SDK request: \(request.url?.path ?? "missing URL")")
            return .failure(URLError(.unsupportedURL))
        }
        return response
    }

    func unregister() { PaymentURLProtocol.unregister(identifier) }
}

private final class PaymentURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var stubs: [String: PaymentNetworkStub] = [:]

    static func register(_ stub: PaymentNetworkStub) {
        lock.lock()
        defer { lock.unlock() }
        stubs[stub.identifier] = stub
    }

    static func unregister(_ identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        stubs.removeValue(forKey: identifier)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let stub = request.value(forHTTPHeaderField: "X-PayHere-Test-ID").flatMap { Self.stubs[$0] }
        Self.lock.unlock()
        guard let stub = stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch stub.respond(to: request) {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .success(let data):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                                 headerFields: ["Content-Type": "application/json"]) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
