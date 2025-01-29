//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//

import Foundation
import SwiftUI

// MARK: - Public Enums

public enum FeeMode: String, Codable {
    case merchantFee = "merchant_fee"
    case serviceFee = "service_fee"
}

public enum PaymentType: String, CaseIterable, Identifiable {
    case card = "Card"
    case ach = "ACH"
    case cash = "Cash"
    case applePay = "ApplePay"
    public var id: Self { self }
}

public enum HealthExpenseType: String, Encodable {
    case healthcare = "HEALTHCARE"
    case perscription = "RX"
    case vision = "VISION"
    case clinical = "CLINICAL"
    case copay = "COPAY"
    case dental = "DENTAL"
    case transit = "TRANSIT"
}

// MARK: - Message names
//Action Constants
let hostTokenMessage = "host:hostToken"
let transferMessage = "host:transfer_part1"
let tokenizeMessage = "host:tokenize"
let barcodeMessage = "host:barcode"
let calculateFeeMessage = "host:calculate_fee"
let applePayTransaction = "host:apple_pay_transaction"

// Constants for incoming message types
let hostTokenResponseMessage = "host_token"
let barcodeResponseMessage = "barcode_complete"
let transferResponseMessage = "transfer_complete"
let tokenizeResponseMessage = "tokenize_complete"
let errorResponseMessage = "error"
let calculateFeeResponseMessage = "calculate_fee_complete"

let encryptedMessages = [barcodeResponseMessage, transferResponseMessage, tokenizeResponseMessage]

// MARK: - Extensions to swift foundational
extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

extension String {
    var length: Int {
        return count
    }
    
    subscript (int: Int) -> String {
        return self[int ..< int + 1]
    }
    
    subscript (section: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, section.lowerBound)),
                                            upper: min(length, max(0, section.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

// MARK: - 
