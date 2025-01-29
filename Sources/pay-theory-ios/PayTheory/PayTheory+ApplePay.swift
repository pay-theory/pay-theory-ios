//
//  PayTheory+ApplePay.swift
//  PayTheory
//
//  Created by Pay Theory on 3/19/24.
//

import PassKit
import SwiftUI

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
    
    /// Creates an Apple Pay button view
    /// - Parameters:
    ///   - type: The type of button (default: .plain)
    ///   - style: The button style (default: .black)
    /// - Returns: A SwiftUI view containing the Apple Pay button
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
        .disabled(self.transaction.hostToken == nil)
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
    
    public func configureApplePaySheet(_ config: PTApplePaySheetConfig) {
        applePayHandler.setConfig(config)
    }
    
    
    /// Converts the configuration into a PKPaymentRequest
    func createPaymentRequest(ptRequestConfig: PTApplePayRequestConfig) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        
        // Required fields
        request.merchantIdentifier = ptRequestConfig.merchantIdentifier
        
        // Default country and currency codes
        request.countryCode = self.country ?? "US"
        request.currencyCode = self.currency ?? "USD"
        
        // Payment configuration
        request.supportedNetworks = ptRequestConfig.supportedNetworks
        request.merchantCapabilities = ptRequestConfig.merchantCapabilities
        
        // Contact fields
        request.requiredBillingContactFields = ptRequestConfig.requiredBillingContactFields
        request.requiredShippingContactFields = ptRequestConfig.requiredShippingContactFields
        request.billingContact = ptRequestConfig.billingContact
        request.shippingContact = ptRequestConfig.shippingContact
        
        // Shipping configuration
        request.shippingMethods = ptRequestConfig.shippingMethods
        if let shippingType = ptRequestConfig.shippingType {
            request.shippingType = shippingType
        }
        
        // Additional options
        request.supportsCouponCode = ptRequestConfig.supportsCouponCode
        request.applicationData = ptRequestConfig.applicationData
        
        // Payment summary items
        request.paymentSummaryItems = ptRequestConfig.paymentSummaryItems
        
        return request
    }
    
    
    
}

// Create a separate handler class for Apple Pay
@available(iOS 15.0, *)
class PayTheoryApplePayHandler: NSObject, PKPaymentAuthorizationControllerDelegate {
    weak var payTheory: PayTheory?
    var sheetConfig: PTApplePaySheetConfig?
    var cardType: ApplePayCardType?
    
    func setConfig(_ config: PTApplePaySheetConfig) {
        self.sheetConfig = config
    }
    
    func setPayTheory(_ payTheory: PayTheory) {
        self.payTheory = payTheory
    }

    func calculateServiceFee(amount: Decimal) -> Decimal {
        guard let payTheory = payTheory else { return 0 }
        print("Calculating service fee...")
        print("card type: \(String(describing: cardType))")
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
    
    func updatepaymentSummaryItemsWithServiceFee(_ paymentSummaryItems: inout [PKPaymentSummaryItem]) {
        guard let payTheory = payTheory else { return }
        
        // Look through the paymentSummaryItems. If you find one with Service Fee delete it and also remove that amount from the last items amount
        if let serviceFeeIndex = paymentSummaryItems.firstIndex(where: { $0.label == "Service Fee" }) {
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
                PKPaymentSummaryItem(label: "Amount", amount: NSDecimalNumber(decimal: amount)),
                PKPaymentSummaryItem(label: "Service Fee", amount: NSDecimalNumber(decimal: fee)),
                PKPaymentSummaryItem(label: "Paddy's Pub", amount: NSDecimalNumber(decimal: total))
            ]
        } else {
            let total = (paymentSummaryItems.last?.amount as NSDecimalNumber?)?.decimalValue ?? 0
            let sum = paymentSummaryItems.dropLast().reduce(Decimal(0)) { $0 + ($1.amount as NSDecimalNumber).decimalValue }
            print(sum == total, "Same total: \(sum) != \(total)")
            for item in paymentSummaryItems {
                print(item.label ?? "No label", item.amount ?? 0)
            }
            if total != sum {
                // TODO: Close the sheet
                return
            }
            
            let fee = calculateServiceFee(amount: sum)
            let serviceFeeItem = PKPaymentSummaryItem(label: "Service Fee", amount: NSDecimalNumber(decimal: fee))
            paymentSummaryItems.insert(serviceFeeItem, at: paymentSummaryItems.count - 1)
            paymentSummaryItems[paymentSummaryItems.count - 1].amount = NSDecimalNumber(decimal: total + fee)
        }
        
        self.sheetConfig?.requestConfiguration.paymentSummaryItems = paymentSummaryItems
    }
    
    
    public func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                             didAuthorizePayment payment: PKPayment,
                                             handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        guard let payTheory = payTheory else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }
        
        Task {
            // Convert payment token data to base64 string for transmission
            let paymentData = payment.token.paymentData
            if let string = String(data: paymentData, encoding: .utf8) {
                print(string)
            }
            
            // You can also access additional information if needed
            let network = payment.token.paymentMethod.network?.rawValue ?? ""
            let displayName = payment.token.paymentMethod.displayName ?? ""
            
            // If you need billing contact info
            let billingContact = payment.billingContact
            let billingAddress = Address(
                line1: billingContact?.postalAddress?.street ?? "",
                line2: billingContact?.postalAddress?.subLocality ?? "",
                city: billingContact?.postalAddress?.city ?? "",
                country: billingContact?.postalAddress?.country ?? "",
                region: billingContact?.postalAddress?.state ?? "",
                postalCode: billingContact?.postalAddress?.postalCode ?? ""
            )
            let billingPayor = Payor(firstName: billingContact?.name?.givenName, lastName: billingContact?.name?.familyName, email: billingContact?.emailAddress, phone: billingContact?.phoneNumber?.stringValue, personalAddress: billingAddress)

            let shippingContact = payment.shippingContact
            let shippingAddress = Address(
                line1: shippingContact?.postalAddress?.street ?? "",
                line2: shippingContact?.postalAddress?.subLocality ?? "",
                city: shippingContact?.postalAddress?.city ?? "",
                country: shippingContact?.postalAddress?.country ?? "",
                region: shippingContact?.postalAddress?.state ?? "",
                postalCode: shippingContact?.postalAddress?.postalCode ?? ""
            )
            let shippingPayor = Payor(firstName: shippingContact?.name?.givenName, lastName: shippingContact?.name?.familyName, email: shippingContact?.emailAddress, phone: shippingContact?.phoneNumber?.stringValue, personalAddress: shippingAddress)
            
            let cardType = ApplePayCardType(cardType: payment.token.paymentMethod.type)
            
            // Create token details
            let tokenDetails = ApplePayTokenDetails(
                paymentData: paymentData.base64EncodedString(),
                paymentNetwork: network,
                cardDisplayName: displayName,
                cardType: cardType.rawValue,
                billingDetails: billingPayor,
                shippingDetails: shippingPayor
            )
            
            // Create the payload using ApplePayPaymentData
            let payload = ApplePayPaymentData(
                amount: payTheory.amount ?? 0,
                fee: payTheory.cardServiceFee ?? 0,
                feeMode: .merchantFee,
                tokenDetails: tokenDetails,
                hostToken: self.payTheory?.transaction.hostToken ?? ""
            )
            
            // Encrypt the payload and prepare for transmission
            if let encryptedBody = payTheory.transaction.createApplePayBody(applePayData: payload) {
                // Convert to Data and base64 encode
                if let jsonData = encryptedBody.data(using: .utf8) {
                    let base64EncodedString = jsonData.base64EncodedString()
                    // Use the base64EncodedString for your transaction
                    print(base64EncodedString)
                }
            }
        }
    }
    
    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
    
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
    
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                        didSelectPaymentMethod paymentMethod: PKPaymentMethod,
                                        handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        // Set the card type before doing anything
        self.cardType = ApplePayCardType(cardType: paymentMethod.type)

        if let closure = sheetConfig?.onPaymentMethodUpdate {
            // Calculate any service fees based on the new state
            let update = closure(paymentMethod)
            handlePaymentUpdate(update)
            completion(update)
        } else {
            // If the transaction is set up as serviceFee then we should
            if sheetConfig?.transactionDetails.feeMode == .serviceFee {
                var paymentSummeryItems: [PKPaymentSummaryItem] = sheetConfig!.requestConfiguration.paymentSummaryItems
                updatepaymentSummaryItemsWithServiceFee(&paymentSummeryItems)
                completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: paymentSummeryItems))
            } else {
                completion(PKPaymentRequestPaymentMethodUpdate())
            }
        }
    }

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

@available(iOS 15.0, *)
private struct PayTheoryApplePayButton: UIViewRepresentable {
    let type: PKPaymentButtonType
    let style: PKPaymentButtonStyle
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
