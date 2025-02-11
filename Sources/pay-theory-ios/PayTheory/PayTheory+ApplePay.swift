//
//  PayTheory+ApplePay.swift
//  PayTheory
//
//  Created by Pay Theory on 3/19/24.
//

import PassKit
import SwiftUI

/// PayTheory Apple Pay integration extension
///
/// This extension provides Apple Pay functionality for the PayTheory SDK, including:
/// - Apple Pay availability checks
/// - Apple Pay button creation
/// - Payment request configuration
/// - Payment processing
@available(iOS 15.0, *)
extension PayTheory {
    
    // MARK: - Apple Pay Availability
    
    /// Checks if Apple Pay is available on the device and the merchant is capable of making payments
    /// - Returns: Boolean indicating if Apple Pay can be used
    public func canMakeApplePayments() -> Bool {
        return PKPaymentAuthorizationController.canMakePayments()
    }
    
    /// Checks if specific payment networks are supported
    /// - Parameter networks: Array of payment networks to check (defaults to common networks)
    /// - Returns: Boolean indicating if the specified networks are supported
    public func canMakeApplePayments(supporting networks: [PKPaymentNetwork] = [.visa, .masterCard, .amex]) -> Bool {
        return PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks)
    }
    
    // MARK: - Apple Pay Button
    
    /// Creates an Apple Pay button view with customizable appearance
    ///
    /// This method creates a SwiftUI view containing an Apple Pay button that will be:
    /// - Styled according to the provided parameters
    /// - Automatically disabled if:
    ///   - Apple Pay is not available on the device
    ///   - The Apple Pay sheet is not configured
    ///   - The transaction host token is not set
    /// - Animated when enabling/disabling
    ///
    /// - Parameters:
    ///   - type: The type of button (default: .plain)
    ///   - style: The button style (default: .black)
    /// - Returns: A SwiftUI view containing the configured Apple Pay button
    ///
    /// Example:
    /// ```swift
    /// payTheory.createApplePayButton(
    ///     type: .buy,
    ///     style: .white
    /// )
    /// ```
    public func createApplePayButton(
        type: PKPaymentButtonType = .plain,
        style: PKPaymentButtonStyle = .black
    ) -> some View {
        PayTheoryApplePayButton(
            type: type,
            style: style,
            action: { [weak self] in
                self?.startApplePayPayment()
            }
        )
        .disabled(
            !canMakeApplePayments() || 
            self.applePayHandler.sheetConfig == nil ||
            self.transaction.hostToken == nil
        )
        .animation(.default, value: self.transaction.hostToken != nil)
    }
    
    /// Starts the Apple Pay payment process
    /// - Throws: PTError if the payment setup fails
    private func startApplePayPayment() {
        guard let configuration = self.applePayHandler.sheetConfig?.requestConfiguration else {
            self.errorHandler(PTError(code: .invalidParam, error: "Configuration must be set to use Apple Pay"))
            return
        }
        
        let request = createPaymentRequest(ptRequestConfig: configuration)
        
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = applePayHandler
        
        controller.present { [weak self] success in
            if !success {
                self?.errorHandler(PTError(code: .applePayError, error: "Failed to present Apple Pay"))
            }
        }
    }
    
    /// Configures the Apple Pay payment sheet with custom settings
    ///
    /// Use this method to set up the Apple Pay payment sheet before presenting it to the user.
    /// The configuration includes settings for:
    /// - Merchant identification
    /// - Payment processing capabilities
    /// - Required contact information
    /// - Shipping options
    /// - Line items and totals
    /// - Custom handlers for payment events
    ///
    /// - Parameter config: A configuration object containing all settings for the Apple Pay sheet
    ///
    /// - Note: This must be called before attempting to present the Apple Pay sheet
    ///
    /// Example:
    /// ```swift
    /// let config = PTApplePaySheetConfig(
    ///     merchantIdentifier: "merchant.com.example",
    ///     supportedNetworks: [.visa, .masterCard],
    ///     paymentSummaryItems: [
    ///         PKPaymentSummaryItem(label: "Total", amount: 99.99)
    ///     ]
    /// )
    /// payTheory.configureApplePaySheet(config)
    /// ```
    public func configureApplePaySheet(_ config: PTApplePaySheetConfig) {
        applePayHandler.setConfig(config)
    }
    
    
    /// Creates and configures a PKPaymentRequest object from Pay Theory configuration
    /// - Parameter ptRequestConfig: The Pay Theory configuration object containing Apple Pay settings
    /// - Returns: A fully configured PKPaymentRequest ready for payment processing
    /// - Note: This request object is used to initialize the Apple Pay payment sheet
    func createPaymentRequest(ptRequestConfig: PTApplePayRequestConfig) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        
        // Merchant identifier is required for Apple Pay processing
        // This should match the identifier in your Apple Pay certificate
        request.merchantIdentifier = ptRequestConfig.merchantIdentifier
        
        // Set regional settings with fallbacks to US/USD if not specified
        // These determine the currency display and payment processing region
        request.countryCode = self.country ?? "US"
        request.currencyCode = self.currency ?? "USD"
        
        // Configure supported payment methods and merchant capabilities
        // - supportedNetworks: Available card networks (Visa, Mastercard, etc.)
        // - merchantCapabilities: Payment processing capabilities (3DS, debit, credit)
        request.supportedNetworks = ptRequestConfig.supportedNetworks
        request.merchantCapabilities = ptRequestConfig.merchantCapabilities
        
        // Configure contact information requirements and defaults
        // These determine what information is collected from the user
        // and what fields are pre-filled if available
        request.requiredBillingContactFields = ptRequestConfig.requiredBillingContactFields
        request.requiredShippingContactFields = ptRequestConfig.requiredShippingContactFields
        request.billingContact = ptRequestConfig.billingContact
        request.shippingContact = ptRequestConfig.shippingContact
        
        // Configure shipping options and type
        // - shippingMethods: Available shipping options with prices
        // - shippingType: Delivery method (shipping, delivery, store pickup, etc.)
        request.shippingMethods = ptRequestConfig.shippingMethods
        if let shippingType = ptRequestConfig.shippingType {
            request.shippingType = shippingType
        }
        
        // Set additional payment sheet features
        // - supportsCouponCode: Enables/disables coupon entry field
        // - applicationData: Custom data to pass through the payment
        request.supportsCouponCode = ptRequestConfig.supportsCouponCode
        request.applicationData = ptRequestConfig.applicationData
        
        // Configure the payment summary items
        // These determine what the user sees in the payment breakdown
        // Including line items, tax, shipping, and total
        request.paymentSummaryItems = ptRequestConfig.paymentSummaryItems
        
        return request
    }
    
    func parseApplePayResponse(_ response: String) -> ApplePayResponse {
        let response = parseResponse(response: response)
        if case .failure(let error) = response {
            return .error(error)
        } else if case .success(let (type, parsedBody)) = response {
            switch type {
            case transferResponseMessage:
                if parsedBody["state"] as? String ?? "" == "FAILURE" {
                    resetTransaction()
                    return .failure(FailedTransaction(response: parsedBody))
                } else {
                    setComplete(true)
                    return .success(SuccessfulTransaction(response: parsedBody))
                }
            default:
                return .error(PTError(code: .socketError, error: "Unknown response type: \(type)"))
            }
        }
        resetTransaction()
        return .error(PTError(code: .socketError, error: "Unknown response type."))
    }
}

// MARK: - Apple Pay Delegate

/// Handles Apple Pay payment authorization and delegate methods
///
/// This class manages the Apple Pay payment flow, including:
/// - Payment authorization
/// - Service fee calculations
/// - Payment summary updates
/// - Contact and shipping information handling
@available(iOS 15.0, *)
class PayTheoryApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate {
    weak var payTheory: PayTheory?
    var sheetConfig: PTApplePaySheetConfig?
    var cardType: ApplePayCardType?
    
    /// Sets the configuration for the Apple Pay sheet
    /// - Parameter config: Configuration object containing Apple Pay settings
    func setConfig(_ config: PTApplePaySheetConfig) {
        self.sheetConfig = config
    }
    
    /// Sets the PayTheory instance reference
    /// - Parameter payTheory: The PayTheory instance to handle payments
    func setPayTheory(_ payTheory: PayTheory) {
        self.payTheory = payTheory
    }

    /// Calculates the service fee based on the payment amount and card type
    /// - Parameter amount: The payment amount in decimal format
    /// - Returns: The calculated service fee amount
    func calculateServiceFee(amount: Decimal) -> Decimal {
        guard let payTheory = payTheory else { return 0 }
        // Determine which fee model to use based on card type
        let feeModel = cardType == .debit ? 
        payTheory.debitCardFeeModel :
        payTheory.creditCardFeeModel
        
        // Calculate basis fee (basisPoints are in basis points, i.e. 1/100th of a percent)
        let basisFee = (amount * Decimal(feeModel?.basisPoints ?? 0)) / Decimal(10000)
        
        // Add fixed fee (converting fixed fee from pennies to dollars)
        var totalFee = basisFee + (Decimal(feeModel?.fixed ?? 0) / 100)
        
        // Apply minimum fee if necessary (converting min fee from pennies to dollars)
        let minFeeInDollars = Decimal(feeModel?.minFee ?? 0) / 100
        if totalFee < minFeeInDollars {
            totalFee = minFeeInDollars
        }
        
        return totalFee
    }
    
    /// Updates payment summary items with calculated service fees
    /// - Parameter paymentSummaryItems: Array of payment summary items to update
    /// - Note: This method modifies the items array in place, adding or updating service fee items
    func updatepaymentSummaryItemsWithServiceFee(_ paymentSummaryItems: inout [PKPaymentSummaryItem]) {
        guard let payTheory = payTheory else { return }
        guard let sheetConfig = sheetConfig else { return }
        // Pull out the labels object to use when searching and creating new payment summary items
        var labels = sheetConfig.requestConfiguration.serviceFeeSummaryItemLabels
        
        // Look through the paymentSummaryItems. If you find one with Service Fee delete it and also remove that amount from the last items amount
        if let serviceFeeIndex = paymentSummaryItems.firstIndex(where: { $0.label == labels.serviceFee }) {
            let serviceFeeAmount = (paymentSummaryItems[serviceFeeIndex].amount as NSDecimalNumber).decimalValue
            paymentSummaryItems.remove(at: serviceFeeIndex)
            // Adjust the total amount by removing the service fee
            if let lastIndex = paymentSummaryItems.indices.last {
                let currentTotal = (paymentSummaryItems[lastIndex].amount as NSDecimalNumber).decimalValue
                paymentSummaryItems[lastIndex].amount = NSDecimalNumber(decimal: currentTotal - serviceFeeAmount)
            }
        }
        
        if paymentSummaryItems.count == 1 {
            let amount = paymentSummaryItems[0].amount as Decimal
            let fee = calculateServiceFee(amount: amount)
            let total = amount + fee
            
            paymentSummaryItems = [
                PKPaymentSummaryItem(label: labels.subtotal, amount: NSDecimalNumber(decimal: amount)),
                PKPaymentSummaryItem(label: labels.serviceFee, amount: NSDecimalNumber(decimal: fee)),
                PKPaymentSummaryItem(label: labels.total, amount: NSDecimalNumber(decimal: total))
            ]
        } else {
            let total = (paymentSummaryItems.last?.amount as NSDecimalNumber?)?.decimalValue ?? 0
            let sum = paymentSummaryItems.dropLast().reduce(Decimal(0)) { $0 + ($1.amount as NSDecimalNumber).decimalValue }
            if total != sum {
                // TODO: Close the sheet
                return
            }
            
            let fee = calculateServiceFee(amount: sum)
            let serviceFeeItem = PKPaymentSummaryItem(label: labels.serviceFee, amount: NSDecimalNumber(decimal: fee))
            paymentSummaryItems.insert(serviceFeeItem, at: paymentSummaryItems.count - 1)
            paymentSummaryItems[paymentSummaryItems.count - 1].amount = NSDecimalNumber(decimal: total + fee)
        }
        
        self.sheetConfig?.requestConfiguration.paymentSummaryItems = paymentSummaryItems
    }

    // Finds the service fee in the paymentSummaryItems and returns the amount
    // If no service fee is found, it returns 0
    func getServiceFee(paymentSummaryItems: [PKPaymentSummaryItem]) -> Decimal {
        let feeLabel = sheetConfig?.requestConfiguration.serviceFeeSummaryItemLabels.serviceFee
        return paymentSummaryItems.first(where: { $0.label == feeLabel })?.amount as? Decimal ?? 0
    }

    // Converts a decimal amount to an Int to return the amount in pennies
    func convertAmountToPennies(amount: Decimal) -> Int {
        return NSDecimalNumber(decimal: amount * 100).intValue
    }
    
    /// Handles the payment authorization process after user confirms payment with Apple Pay
    /// - Parameters:
    ///   - controller: The payment authorization controller managing the Apple Pay sheet
    ///   - payment: Contains payment token, billing, and shipping information
    ///   - completion: Callback to inform Apple Pay of the payment result
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Validate PayTheory instance exists before proceeding
        guard let payTheory = payTheory else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }
        
        // Validate the Apple Pay sheet is configured
        guard let sheetConfig = sheetConfig else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }
        
        // Validate that the session doesn't already have a succesfull payment
        if payTheory.isInitialized || payTheory.isComplete {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }
        payTheory.isInitialized = true
        
        Task {
            // SECTION 1: Extract Payment Data
            // Convert Apple Pay token data into required format
            let paymentData = payment.token.paymentData
            let network = payment.token.paymentMethod.network?.rawValue ?? ""
            let displayName = payment.token.paymentMethod.displayName ?? ""
            
            // SECTION 2: Process Billing Information
            // Extract billing contact details and create Address object
            var billingPayor: Payor? = nil
            if let billingContact = payment.billingContact {
                let billingAddress = Address(
                    line1: billingContact.postalAddress?.street,
                    line2: billingContact.postalAddress?.subLocality,
                    city: billingContact.postalAddress?.city,
                    country: billingContact.postalAddress?.country,
                    region: billingContact.postalAddress?.state,
                    postalCode: billingContact.postalAddress?.postalCode
                )
                
                // Create Payor object with billing contact information
                billingPayor = Payor(
                    firstName: billingContact.name?.givenName,
                    lastName: billingContact.name?.familyName,
                    email: billingContact.emailAddress,
                    phone: billingContact.phoneNumber?.stringValue,
                    personalAddress: billingAddress
                )
            }

            // SECTION 3: Process Shipping Information
            // Similar to billing, create Address and Payor objects for shipping
            var shippingPayor: Payor? = nil
            if let shippingContact = payment.shippingContact {
                let shippingAddress = Address(
                    line1: shippingContact.postalAddress?.street,
                    line2: shippingContact.postalAddress?.subLocality,
                    city: shippingContact.postalAddress?.city,
                    country: shippingContact.postalAddress?.country,
                    region: shippingContact.postalAddress?.state,
                    postalCode: shippingContact.postalAddress?.postalCode
                )
                shippingPayor = Payor(
                    firstName: shippingContact.name?.givenName,
                    lastName: shippingContact.name?.familyName,
                    email: shippingContact.emailAddress,
                    phone: shippingContact.phoneNumber?.stringValue,
                    personalAddress: shippingAddress
                )
            }
            
            // SECTION 4: Create Payment Token
            // Determine card type and create token details
            let cardType = ApplePayCardType(cardType: payment.token.paymentMethod.type)
            let tokenDetails = ApplePayTokenDetails(
                paymentData: paymentData.base64EncodedString(),
                paymentNetwork: network,
                cardDisplayName: displayName,
                cardType: cardType.rawValue,
                billingDetails: billingPayor,
                shippingDetails: shippingPayor
            )
            
            // SECTION 5: Create Final Payment Payload
            // Combine all information into final payment structure
            // Pull the amount and service fee from the paymentSummaryItems
            let amount = sheetConfig.requestConfiguration.paymentSummaryItems.last?.amount as? Decimal ?? 0
            let fee = getServiceFee(paymentSummaryItems: sheetConfig.requestConfiguration.paymentSummaryItems)
            let payload = ApplePayPaymentData(
                amount: convertAmountToPennies(amount: amount),
                fee: convertAmountToPennies(amount: fee),
                feeMode: sheetConfig.transactionDetails.feeMode,
                tokenDetails: tokenDetails,
                transaction_details: sheetConfig.transactionDetails
            )
            
            // SECTION 6: Payment Processing
            if let encryptedBody = payTheory.transaction.createApplePayBody(applePayData: payload) {
                // SECTION 6A: Full Payment Processing Flow
                if let callback = payTheory.applePayHandler.sheetConfig?.onPaymentCompletion {
                    do {
                        // Ensure connection and process payment
                        try await payTheory.ensureConnected()
                        let response = try await payTheory.session.sendMessageAndWaitForResponse(messageBody: encryptedBody)
                        let applePayResponse = try payTheory.parseApplePayResponse(response)
                        callback(applePayResponse)
                        
                        // Complete Apple Pay sheet based on response
                        if case .success(_) = applePayResponse {
                            completion(PKPaymentAuthorizationResult(status: .success, errors: []))
                            payTheory.isComplete = true
                        } else {
                            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                            payTheory.isInitialized = false
                        }
                    } catch {
                        // Handle payment processing errors
                        payTheory.errorHandler(PTError(code: .applePayError, error: "Failed to process Apple Pay payment"))
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                        payTheory.isInitialized = false
                    }
                } 
                // SECTION 6B: Tokenization-Only Flow
                else if let jsonData = encryptedBody.data(using: .utf8) {
                    // Convert encrypted body to base64 for tokenization
                    let base64EncodedString = jsonData.base64EncodedString()
                    if let callback = payTheory.applePayHandler.sheetConfig?.onPaymentTokenizationCompletion {
                        let success = callback(base64EncodedString)
                        completion(PKPaymentAuthorizationResult(
                            status: success ? .success : .failure,
                            errors: []
                        ))
                        if success {
                            payTheory.isComplete = false
                        } else {
                            payTheory.isInitialized = false
                        }
                    } else {
                        payTheory.handleError(error: PTError.init(code: .applePayError, error: "No completion handler set to process Apple Pay payment"))
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                        payTheory.isInitialized = false
                    }
                } else {
                    payTheory.handleError(error: PTError.init(code: .applePayError, error: "Error encrypting the Apple Pay payload for processing"))
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                    payTheory.isInitialized = false
                }
            }
        }
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
    
    /// Processes payment request updates, including service fee calculations
    /// - Parameter update: The payment request update to process
    /// - Returns: The processed payment request update
    func handlePaymentUpdate(_ update: PKPaymentRequestUpdate) -> PKPaymentRequestUpdate {
        if sheetConfig?.transactionDetails.feeMode == .serviceFee {
            if !update.paymentSummaryItems.isEmpty {
                var updatedItems = update.paymentSummaryItems
                updatepaymentSummaryItemsWithServiceFee(&updatedItems)
                update.paymentSummaryItems = updatedItems
                return update
            } else {
                var configItems = sheetConfig?.requestConfiguration.paymentSummaryItems ?? []
                updatepaymentSummaryItemsWithServiceFee(&configItems)
                update.paymentSummaryItems = configItems
                return update
            }
        }
        return update
    }
    
    /// Handles coupon code changes in the Apple Pay sheet
    /// - Parameters:
    ///   - controller: The payment authorization controller
    ///   - couponCode: The entered coupon code
    ///   - completion: Callback to update the payment sheet with new totals
    /// - Note: If no coupon handler is configured, completes with empty update
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didChangeCouponCode couponCode: String,
        handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void
    ) {
        if let closure = sheetConfig?.onCouponCodeUpdate {
            let update = closure(couponCode)
            handlePaymentUpdate(update)
            completion(update)
        } else {
            completion(PKPaymentRequestCouponCodeUpdate())
        }
    }
    
    /// Handles shipping contact changes in the Apple Pay sheet
    /// - Parameters:
    ///   - controller: The payment authorization controller
    ///   - contact: The selected shipping contact information
    ///   - completion: Callback to update shipping options and totals
    /// - Note: Updates shipping rates and totals based on new address if handler configured
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingContact contact: PKContact,
        handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        if let closure = sheetConfig?.onShippingContactUpdate {
            let update = closure(contact)
            handlePaymentUpdate(update)
            completion(update)
        } else {
            completion(PKPaymentRequestShippingContactUpdate())
        }
    }
    
    /// Handles payment method selection changes in the Apple Pay sheet
    /// - Parameters:
    ///   - controller: The payment authorization controller
    ///   - paymentMethod: The selected payment method (card type)
    ///   - completion: Callback to update totals based on payment method
    /// - Note: Updates service fees if applicable based on card type (credit/debit)
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectPaymentMethod paymentMethod: PKPaymentMethod,
        handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void
    ) {
        // Store the selected card type for fee calculations
        self.cardType = ApplePayCardType(cardType: paymentMethod.type)

        if let closure = sheetConfig?.onPaymentMethodUpdate {
            // Use custom handler if configured
            let update = closure(paymentMethod)
            handlePaymentUpdate(update)
            completion(update)
        } else {
            // Handle automatic service fee updates if enabled
            if sheetConfig?.transactionDetails.feeMode == .serviceFee {
                var paymentSummeryItems: [PKPaymentSummaryItem] = sheetConfig!.requestConfiguration.paymentSummaryItems
                updatepaymentSummaryItemsWithServiceFee(&paymentSummeryItems)
                completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: paymentSummeryItems))
            } else {
                completion(PKPaymentRequestPaymentMethodUpdate())
            }
        }
    }

    /// Handles shipping method selection changes in the Apple Pay sheet
    /// - Parameters:
    ///   - controller: The payment authorization controller
    ///   - shippingMethod: The selected shipping method
    ///   - completion: Callback to update totals based on shipping method
    /// - Note: Updates total amount with new shipping costs if handler configured
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod,
        handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void
    ) {
        if let closure = sheetConfig?.onShippingMethodUpdate {
            let update = closure(shippingMethod)
            handlePaymentUpdate(update)
            completion(update)
        } else {
            completion(PKPaymentRequestShippingMethodUpdate())
        }
    }
}

// MARK: - Apple Pay Button View
/// A SwiftUI wrapper for the Apple Pay payment button
///
/// This view creates and manages a native PKPaymentButton with customizable appearance and behavior
@available(iOS 15.0, *)
private struct PayTheoryApplePayButton: UIViewRepresentable {
    /// The type of Apple Pay button to display
    let type: PKPaymentButtonType
    
    /// The visual style of the button
    let style: PKPaymentButtonStyle
    
    /// The action to perform when the button is tapped
    let action: () -> Void
    
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            action()
        }
    }
}
