//
//  ApplePay.swift
//  PayTheory
//
//  Created by Austin Zani on 1/27/25.
//

import PassKit

// MARK: - Apple Pay Specific Enums

enum ApplePayCardType: String, CaseIterable {
    case card = "CARD"
    case debit = "DEBIT"
    
    init(cardType: PKPaymentMethodType) {
        if cardType == .debit || cardType == .prepaid || cardType == .eMoney {
            self = .debit
        } else {
            self = .card
        }
    }
}

/// Represents the possible responses from a transaction operation.
public enum ApplePayResponse {
    /// Represents an error in the transaction process.
    case error(PTError)
    /// Represents a failed transaction.
    case failure(FailedTransaction)
    /// Represents a successful transaction.
    case success(SuccessfulTransaction)
}

// MARK: - Apple Pay Configuration

public struct PTApplePaySheetConfig {
    public var requestConfiguration: PTApplePayRequestConfig
    public var transactionDetails: ApplePayTransactionDetails
    public var onPaymentCompletion: ((ApplePayResponse) -> Void)?
    public var onPaymentTokenizationCompletion: ((String) -> Bool)?
    public var onPaymentMethodUpdate: ((PKPaymentMethod) -> PKPaymentRequestPaymentMethodUpdate)?
    public var onShippingContactUpdate: ((PKContact) -> PKPaymentRequestShippingContactUpdate)?
    public var onShippingMethodUpdate: ((PKShippingMethod) -> PKPaymentRequestShippingMethodUpdate)?
    public var onCouponCodeUpdate: ((String) -> PKPaymentRequestCouponCodeUpdate)?
    
    public init(
        requestConfiguration: PTApplePayRequestConfig,
        transactionDetails: ApplePayTransactionDetails = ApplePayTransactionDetails(),
        onPaymentCompletion: ((ApplePayResponse) -> Void)? = nil,
        onPaymentTokenizationCompletion: ((String) -> Bool)? = nil,
        onPaymentMethodUpdate: ((PKPaymentMethod) -> PKPaymentRequestPaymentMethodUpdate)? = nil,
        onShippingContactUpdate: ((PKContact) -> PKPaymentRequestShippingContactUpdate)? = nil,
        onShippingMethodUpdate: ((PKShippingMethod) -> PKPaymentRequestShippingMethodUpdate)? = nil,
        onCouponCodeUpdate: ((String) -> PKPaymentRequestCouponCodeUpdate)? = nil
    ) {
        self.requestConfiguration = requestConfiguration
        self.transactionDetails = transactionDetails
        self.onPaymentCompletion = onPaymentCompletion
        self.onPaymentTokenizationCompletion = onPaymentTokenizationCompletion
        self.onPaymentMethodUpdate = onPaymentMethodUpdate
        self.onShippingContactUpdate = onShippingContactUpdate
        self.onShippingMethodUpdate = onShippingMethodUpdate
        self.onCouponCodeUpdate = onCouponCodeUpdate
    }
}

public struct serviceFeeSummaryItemLabels {
    public var serviceFee: String
    public var total: String
    public var subtotal: String
    
    public init(serviceFee: String = "Service Fee", total: String = "Total", subtotal: String = "Subtotal") {
        self.serviceFee = serviceFee
        self.total = total
        self.subtotal = subtotal
    }
}

/// Configuration options for Apple Pay payment sheet
public struct PTApplePayRequestConfig {
    // Required
    let merchantIdentifier: String
    var paymentSummaryItems: [PKPaymentSummaryItem]
    
    // Payment Networks & Capabilities
    public var supportedNetworks: [PKPaymentNetwork]
    public var merchantCapabilities: PKMerchantCapability
    
    // Contact Fields
    public var requiredBillingContactFields: Set<PKContactField>
    public var requiredShippingContactFields: Set<PKContactField>
    public var billingContact: PKContact?
    public var shippingContact: PKContact?
    
    // Shipping
    public var shippingMethods: [PKShippingMethod]?
    public var shippingType: PKShippingType?
    
    // Additional Options
    public var supportsCouponCode: Bool
    public var applicationData: Data?
    public var serviceFeeSummaryItemLabels: serviceFeeSummaryItemLabels
    
    public init(
        merchantIdentifier: String,
        paymentSummaryItems: [PKPaymentSummaryItem],
        supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex],
        merchantCapabilities: PKMerchantCapability = .capability3DS,
        requiredBillingContactFields: Set<PKContactField> = [],
        requiredShippingContactFields: Set<PKContactField> = [],
        billingContact: PKContact? = nil,
        shippingContact: PKContact? = nil,
        shippingMethods: [PKShippingMethod]? = nil,
        shippingType: PKShippingType? = nil,
        supportsCouponCode: Bool = false,
        applicationData: Data? = nil,
        serviceFeeSummaryItemLabels: serviceFeeSummaryItemLabels = .init()) {
        self.merchantIdentifier = merchantIdentifier
        self.paymentSummaryItems = paymentSummaryItems
        self.supportedNetworks = supportedNetworks
        self.merchantCapabilities = merchantCapabilities
        self.requiredBillingContactFields = requiredBillingContactFields
        self.requiredShippingContactFields = requiredShippingContactFields
        self.billingContact = billingContact
        self.shippingContact = shippingContact
        self.shippingMethods = shippingMethods
        self.shippingType = shippingType
        self.supportsCouponCode = supportsCouponCode
        self.applicationData = applicationData
        self.serviceFeeSummaryItemLabels = serviceFeeSummaryItemLabels
    }
}

// MARK: - Apple Pay Payment Details Object

public struct ApplePayTokenDetails: Encodable {
    let paymentData: String
    let paymentNetwork: String
    let cardDisplayName: String
    let cardType: String
    let billingDetails: Payor
    let shippingDetails: Payor
    
    enum CodingKeys: String, CodingKey {
        case paymentData = "payment_data"
        case paymentNetwork = "payment_network"
        case cardDisplayName = "card_display_name"
        case cardType = "card_type"
        case billingDetails = "billing_details"
        case shippingDetails = "shipping_details"
    }
}

public struct ApplePayPaymentData: Encodable {
    let amount: Int
    let fee: Int
    let feeMode: FeeMode
    let tokenDetails: ApplePayTokenDetails
    let walletType: String
    let origin: String
    let hostToken: String
    let appId: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case fee
        case feeMode = "fee_mode"
        case hostToken = "host_token"
        case origin
        case tokenDetails = "token_details"
        case walletType = "wallet_type"
        case appId = "app_id"
    }
    
    public init(amount: Int, fee: Int = 0, feeMode: FeeMode, tokenDetails: ApplePayTokenDetails, hostToken: String) {
        let bundleId = Bundle.main.bundleIdentifier ?? ""

        self.amount = amount
        self.fee = fee
        self.feeMode = feeMode
        self.tokenDetails = tokenDetails
        self.hostToken = hostToken
        self.walletType = "APPLE_PAY"
        self.origin = "NATIVE"
        self.appId = bundleId
    }
}

public struct ApplePayTransactionDetails: Encodable {
    public var accountCode: String?
    public var feeMode: FeeMode
    public var healthExpenseType: HealthExpenseType?
    public var invoiceId: String?
    public var level3DataSummary: Level3DataSummary?
    public var metadata: [String: String]?
    public var payor: Payor?
    public var payorId: String?
    public var receiptDescription: String?
    public var recurringId: String?
    public var reference: String?
    public var sendReceipt: Bool
    
    enum CodingKeys: String, CodingKey {
        case accountCode = "account_code"
        case feeMode = "fee_mode"
        case healthExpenseType = "health_expense_type"
        case invoiceId = "invoice_id"
        case level3DataSummary = "level3_data_summary"
        case metadata
        case payor
        case payorId = "payor_id"
        case receiptDescription = "receipt_description"
        case recurringId = "recurring_id"
        case reference
        case sendReceipt = "send_receipt"
    }
    
    public init(
        accountCode: String? = nil,
        feeMode: FeeMode = .merchantFee,
        healthExpenseType: HealthExpenseType? = nil,
        invoiceId: String? = nil,
        level3DataSummary: Level3DataSummary? = nil,
        metadata: [String: String]? = nil,
        payor: Payor? = nil,
        payorId: String? = nil,
        receiptDescription: String? = nil,
        recurringId: String? = nil,
        reference: String? = nil,
        sendReceipt: Bool = false
    ) {
        self.accountCode = accountCode
        self.feeMode = feeMode
        self.healthExpenseType = healthExpenseType
        self.invoiceId = invoiceId
        self.level3DataSummary = level3DataSummary
        self.metadata = metadata
        self.payor = payor
        self.payorId = payorId
        self.receiptDescription = receiptDescription
        self.recurringId = recurringId
        self.reference = reference
        self.sendReceipt = sendReceipt
    }
}

