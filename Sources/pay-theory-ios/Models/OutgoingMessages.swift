//
//  OutgoingMessages.swift
//  PayTheory
//
//  Created by Austin Zani on 10/2/24.
//

import Foundation

enum PaymentMethodData: Encodable {
    case card(CardStruct)
    case ach(ACHStruct)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .card(let cardData):
            try container.encode(cardData)
        case .ach(let achData):
            try container.encode(achData)
        }
    }
}

// Represents the data for cash payments
struct CashPaymentData: Encodable {
    let hostToken: String
    let sessionKey: String
    let timing: Int64
    let payorInfo: Payor?
    let payTheoryData: PayTheoryData
    let metadata: [String: String]
    let payment: CashStruct
    
    enum CodingKeys: String, CodingKey {
        case hostToken
        case sessionKey = "session_key"
        case timing
        case payorInfo = "payor_info"
        case payTheoryData = "pay_theory_data"
        case metadata
        case payment
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hostToken, forKey: .hostToken)
        try container.encode(sessionKey, forKey: .sessionKey)
        try container.encode(timing, forKey: .timing)
        try container.encode(payorInfo, forKey: .payorInfo)
        try container.encode(payTheoryData, forKey: .payTheoryData)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(payment, forKey: .payment)
    }
}

// Represents the data for transfer payments (part one)
struct TransferPartOneData: Encodable {
    let hostToken: String
    let sessionKey: String
    let timing: Int64
    let payorInfo: Payor?
    let payTheoryData: PayTheoryData
    let metadata: [String: String]
    let paymentMethodData: PaymentMethodData
    let paymentData: PaymentData
    let confirmationNeeded: Bool
    
    enum CodingKeys: String, CodingKey {
        case hostToken
        case sessionKey = "session_key"
        case timing = "timing"
        case payorInfo = "payor_info"
        case payTheoryData = "pay_theory_data"
        case metadata = "metadata"
        case paymentMethodData = "payment_method_data"
        case paymentData = "payment_data"
        case confirmationNeeded = "confirmation_needed"
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hostToken, forKey: .hostToken)
        try container.encode(sessionKey, forKey: .sessionKey)
        try container.encode(timing, forKey: .timing)
        try container.encode(payorInfo, forKey: .payorInfo)
        try container.encode(payTheoryData, forKey: .payTheoryData)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(paymentMethodData, forKey: .paymentMethodData)
        try container.encode(paymentData, forKey: .paymentData)
        try container.encode(confirmationNeeded, forKey: .confirmationNeeded)
    }
}

// Represents the data for tokenizing a payment method
struct TokenizePaymentMethodData: Encodable {
    let hostToken: String
    let sessionKey: String
    let timing: Int64
    let payorInfo: Payor?
    let payTheoryData: TokenizationPayTheoryData
    let metadata: [String: String]
    let paymentMethodData: PaymentMethodData
    
    enum CodingKeys: String, CodingKey {
        case hostToken
        case sessionKey = "session_key"
        case timing = "timing"
        case payorInfo = "payor_info"
        case payTheoryData = "pay_theory_data"
        case metadata = "metadata"
        case paymentMethodData = "payment_method_data"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hostToken, forKey: .hostToken)
        try container.encode(sessionKey, forKey: .sessionKey)
        try container.encode(timing, forKey: .timing)
        try container.encode(payorInfo, forKey: .payorInfo)
        try container.encode(payTheoryData, forKey: .payTheoryData)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(paymentMethodData, forKey: .paymentMethodData)
    }
}

struct PaymentData: Codable {
    let feeMode: FeeMode
    let currency: String
    let amount: Int
    
    enum CodingKeys: String, CodingKey {
        case feeMode = "fee_mode"
        case currency = "currency"
        case amount = "amount"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feeMode, forKey: .feeMode)
        try container.encode(currency, forKey: .currency)
        try container.encode(amount, forKey: .amount)
    }
}

struct TokenizationPayTheoryData: Codable {
    let payorId: String?
    
    enum CodingKeys: String, CodingKey {
        case payorId = "payor_id"
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(payorId, forKey: .payorId)
    }
}

struct PayTheoryData: Encodable {
    let accountCode: String?
    let fee: Int?
    let healthExpenseType: HealthExpenseType?
    let invoiceId: String?
    let level3DataSummary: Level3DataSummary?
    let oneTimeUseToken: Bool
    let payorId: String?
    let receiptDescription: String?
    let recurringId: String?
    let reference: String?
    let sendReceipt: Bool
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case accountCode = "account_code"
        case fee
        case healthExpenseType
        case invoiceId = "invoice_id"
        case level3DataSummary
        case oneTimeUseToken
        case payorId = "payor_id"
        case receiptDescription = "receipt_description"
        case recurringId = "recurring_id"
        case reference
        case sendReceipt = "send_receipt"
        case timezone
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.accountCode, forKey: .accountCode)
        try container.encode(self.fee, forKey: .fee)
        try container.encode(self.healthExpenseType, forKey: .healthExpenseType)
        try container.encode(self.invoiceId, forKey: .invoiceId)
        try container.encode(self.level3DataSummary, forKey: .level3DataSummary)
        try container.encode(self.oneTimeUseToken, forKey: .oneTimeUseToken)
        try container.encode(self.payorId, forKey: .payorId)
        try container.encode(self.receiptDescription, forKey: .receiptDescription)
        try container.encode(self.recurringId, forKey: .recurringId)
        try container.encode(self.reference, forKey: .reference)
        try container.encode(self.sendReceipt, forKey: .sendReceipt)
        try container.encode(self.timezone, forKey: .timezone)
    }

    init(accountCode: String?,
         fee: Int?,
         healthExpenseType: HealthExpenseType?,
         invoiceId: String?,
         level3DataSummary: Level3DataSummary?,
         oneTimeUseToken: Bool?,
         payorId: String?,
         receiptDescription: String?,
         recurringId: String?,
         reference: String?,
         sendReceipt: Bool?,
         metadata: [String: String]?) {
        self.accountCode = accountCode ?? metadata?["pay-theory-account-code"] as? String
        self.fee = fee
        self.healthExpenseType = healthExpenseType
        self.invoiceId = invoiceId
        self.level3DataSummary = level3DataSummary
        self.oneTimeUseToken = oneTimeUseToken ?? false
        self.payorId = payorId
        self.receiptDescription = receiptDescription ?? metadata?["pay-theory-receipt-description"] as? String
        self.recurringId = recurringId
        self.reference = reference ?? metadata?["pay-theory-reference"] as? String
        self.sendReceipt = sendReceipt ?? metadata?["pay-theory-receipt"] as? Bool ?? false
        self.timezone = TimeZone.current.identifier
    }
}
