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
    /// Configuration for the Apple Pay payment request, including merchant details,
    /// supported payment networks, and required billing/shipping fields.
    public var requestConfiguration: PTApplePayRequestConfig
    
    /// Details about you would want to include with the transaction.
    public var transactionDetails: ApplePayTransactionDetails
    
    /// Callback executed when a payment is completed through Apple Pay.
    /// - Parameter response: An `ApplePayResponse` containing the result of the payment processing
    /// - Returns: Void
    public var onPaymentCompletion: ((ApplePayResponse) -> Void)?
    
    /// Callback for tokenization-only flow, where the payment is not processed immediately.
    /// - Parameter token: A base64 encoded string containing the encrypted payment details
    /// - Returns: Boolean indicating if the payment was successful. This boolean indicator will inform us how to handle dismissing the Apple Pay sheet.
    public var onPaymentTokenizationCompletion: ((String) -> Bool)?
    
    /// Callback triggered when the user changes their payment method in the Apple Pay sheet.
    /// Use this to update totals based on the selected payment method (e.g., different fees for different card types).
    /// - Parameter method: The selected PKPaymentMethod containing card details
    /// - Returns: An update object that can modify the payment request
    public var onPaymentMethodUpdate: ((PKPaymentMethod) -> PKPaymentRequestPaymentMethodUpdate)?
    
    /// Callback triggered when the user updates their shipping contact information.
    /// Use this to recalculate shipping costs or validate shipping addresses.
    /// - Parameter contact: The updated shipping contact information
    /// - Returns: An update object that can modify shipping options and total amount
    public var onShippingContactUpdate: ((PKContact) -> PKPaymentRequestShippingContactUpdate)?
    
    /// Callback triggered when the user selects a different shipping method.
    /// Use this to update the total amount based on the selected shipping option.
    /// - Parameter method: The selected shipping method
    /// - Returns: An update object that can modify the payment request
    public var onShippingMethodUpdate: ((PKShippingMethod) -> PKPaymentRequestShippingMethodUpdate)?
    
    /// Callback triggered when the user enters or updates a coupon code.
    /// Use this to validate the coupon and update the total amount accordingly.
    /// - Parameter code: The entered coupon code
    /// - Returns: An update object that can modify the payment request
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
    /// The Apple Pay merchant identifier obtained from your Apple Developer account.
    /// This unique identifier is required to process Apple Pay payments.
    let merchantIdentifier: String
    
    /// An array of line items displayed in the payment sheet, including subtotal, tax,
    /// shipping costs, and total amount. The last item in this array represents the final total.
    var paymentSummaryItems: [PKPaymentSummaryItem]
    
    /// The payment networks that your merchant account supports.
    /// Defaults to [.visa, .masterCard, .amex].
    /// - Note: Your merchant account must be configured to accept payments from these networks.
    public var supportedNetworks: [PKPaymentNetwork]
    
    /// The payment processing capabilities of your merchant account.
    /// Defaults to .capability3DS (supports 3D Secure protocol).
    /// - Note: 3DS capability is required for most credit card processing.
    public var merchantCapabilities: PKMerchantCapability
    
    /// The billing contact fields that must be collected from the customer.
    /// Examples include name, email, phone, and postal address.
    /// - Note: Only requested fields will be available in the payment response.
    public var requiredBillingContactFields: Set<PKContactField>
    
    /// The shipping contact fields that must be collected from the customer.
    /// Similar to billing fields, but for delivery information.
    /// - Note: Only relevant if physical goods are being purchased.
    public var requiredShippingContactFields: Set<PKContactField>
    
    /// Pre-filled billing contact information to display in the payment sheet.
    /// Useful when the customer's billing information is already known.
    public var billingContact: PKContact?
    
    /// Pre-filled shipping contact information to display in the payment sheet.
    /// Useful when the customer's shipping information is already known.
    public var shippingContact: PKContact?
    
    /// Available shipping methods and their costs.
    /// Each method includes a label, detail, and price.
    /// - Note: Can be updated dynamically based on the shipping address.
    public var shippingMethods: [PKShippingMethod]?
    
    /// The type of shipping to be used for the purchase.
    /// Affects the shipping method interface in the payment sheet.
    public var shippingType: PKShippingType?
    
    /// Indicates whether the payment sheet should display a coupon code entry field.
    /// When enabled, the `onCouponCodeUpdate` callback will be triggered when codes are entered.
    public var supportsCouponCode: Bool
    
    /// Additional data to be passed with the payment.
    /// This data will be available in the payment token for server-side processing.
    public var applicationData: Data?
    
    /// Custom labels for service fee line items in the payment summary.
    /// Allows customization of how fees are displayed to the customer.
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
        serviceFeeSummaryItemLabels: serviceFeeSummaryItemLabels = .init()
    ) {
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
    let billingDetails: Payor?
    let shippingDetails: Payor?

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.paymentData, forKey: .paymentData)
        try container.encode(self.paymentNetwork, forKey: .paymentNetwork)
        try container.encode(self.cardDisplayName, forKey: .cardDisplayName)
        try container.encode(self.cardType, forKey: .cardType)
        try container.encode(self.billingDetails, forKey: .billingDetails)
        try container.encode(self.shippingDetails, forKey: .shippingDetails)
    }
    
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
    let transactionDetails: ApplePayTransactionDetails
    let walletType: String
    let origin: String
    let appId: String
    let timing: Int64

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.amount, forKey: .amount)
        try container.encode(self.fee, forKey: .fee)
        try container.encode(self.feeMode, forKey: .feeMode)
        try container.encode(self.origin, forKey: .origin)
        try container.encode(self.tokenDetails, forKey: .tokenDetails)
        try container.encode(self.walletType, forKey: .walletType)
        try container.encode(self.appId, forKey: .appId)
        try container.encode(self.transactionDetails, forKey: .transactionDetails)
        try container.encode(self.timing, forKey: .timing)
    }
    
    enum CodingKeys: String, CodingKey {
        case amount
        case fee
        case feeMode = "fee_mode"
        case origin
        case tokenDetails = "token_details"
        case walletType = "wallet_type"
        case appId = "app_id"
        case transactionDetails = "transaction_details"
        case timing
    }
    
    public init(amount: Int, fee: Int = 0, feeMode: FeeMode, tokenDetails: ApplePayTokenDetails, transaction_details: ApplePayTransactionDetails) {
        let bundleId = Bundle.main.bundleIdentifier ?? ""

        self.amount = amount
        self.fee = fee
        self.feeMode = feeMode
        self.tokenDetails = tokenDetails
        self.walletType = "APPLE_PAY"
        self.origin = "NATIVE"
        self.appId = bundleId
        self.timing = Date().millisecondsSince1970
        self.transactionDetails = transaction_details
    }
}

/// Additional details and metadata for an Apple Pay transaction
public struct ApplePayTransactionDetails: Encodable {
    /// Optional account code for transaction categorization or routing.
    /// Used to associate transactions with specific accounting categories or departments.
    public var accountCode: String?
    
    /// Determines how processing fees are handled in the transaction.
    /// Specifies whether merchant pays fees or if they're passed to the customer.
    public var feeMode: FeeMode
    
    /// For healthcare-related transactions, specifies the type of health expense.
    /// Used for HSA/FSA payment processing and compliance.
    public var healthExpenseType: HealthExpenseType?
    
    /// Optional identifier linking the transaction to a specific invoice.
    /// Useful for reconciliation and tracking purposes.
    public var invoiceId: String?
    
    /// Enhanced transaction data for level 3 processing.
    /// Provides detailed line-item information for B2B and government transactions.
    public var level3DataSummary: Level3DataSummary?
    
    /// Custom key-value pairs for additional transaction information.
    /// Can be used for internal tracking, integration with other systems, or custom business logic.
    public var metadata: [String: String]?
    
    /// Detailed information about the person making the payment.
    /// Includes contact information and address details.
    public var payor: Payor?
    
    /// Unique identifier for the payor in your system.
    /// Used to link transactions to specific customer records.
    public var payorId: String?
    
    /// Custom description to appear on receipts and transaction records.
    /// Helps customers identify the purpose of the transaction.
    public var receiptDescription: String?
    
    /// Identifier for recurring payment series.
    /// Links this transaction to a recurring payment schedule or subscription.
    public var recurringId: String?
    
    /// Custom reference number for the transaction.
    /// Can be used for internal tracking or cross-referencing with other systems.
    public var reference: String?
    
    /// Indicates whether to send a receipt to the customer.
    /// When true, triggers automatic receipt delivery to customer's email.
    public var sendReceipt: Bool
    
    // Timezone from the device used for the transaction
    var timezone: String

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.accountCode, forKey: .accountCode)
        try container.encode(self.feeMode, forKey: .feeMode)
        try container.encode(self.healthExpenseType, forKey: .healthExpenseType)
        try container.encode(self.invoiceId, forKey: .invoiceId)
        try container.encode(self.level3DataSummary, forKey: .level3DataSummary)
        try container.encode(self.metadata, forKey: .metadata)
        try container.encode(self.payor, forKey: .payor)
        try container.encode(self.payorId, forKey: .payorId)
        try container.encode(self.receiptDescription, forKey: .receiptDescription)
        try container.encode(self.recurringId, forKey: .recurringId)
        try container.encode(self.reference, forKey: .reference)
        try container.encode(self.sendReceipt, forKey: .sendReceipt)
        try container.encode(self.timezone, forKey: .timezone)
    }
    
    /// Mapping of property names to their JSON representation
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
        case timezone
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
        self.timezone = TimeZone.current.identifier
    }
}
