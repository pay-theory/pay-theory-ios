//
//  ACHFields.swift
//  PayTheory
//
//  Created by Austin Zani on 3/15/21.
//
import SwiftUI
import Foundation
import Combine

enum ACHAccountType: String, CaseIterable, Encodable {
    case checking = "CHECKING"
    case savings = "SAVINGS"
    
    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        }
    }
}

struct ACHStruct: Encodable {
    var accountNumber = ""
    var accountType = ACHAccountType.checking
    var bankCode = ""
    var name = ""
    let issuingCountryCode = "USA"
    let type = "ach"
    
    private enum CodingKeys: String, CodingKey {
        case accountNumber = "account_number"
        case accountType = "account_type"
        case bankCode = "bank_code"
        case name
        case issuingCountryCode = "issuing_country_code"
        case type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountNumber, forKey: .accountNumber)
        try container.encode(bankCode, forKey: .bankCode)
        try container.encode(name, forKey: .name)
        try container.encode(accountType, forKey: .accountType)
        try container.encode(issuingCountryCode, forKey: .issuingCountryCode)
        try container.encode(type, forKey: .type)
    }
    
    mutating func clear() {
        self.accountNumber = ""
        self.accountType = .checking
        self.bankCode = ""
        self.name = ""
    }
}

class ACH: ObservableObject {
    @Published var ach: ACHStruct
    @Published var isValid: Bool = false
    @Published var validBankCode: Bool = false
    @Published var validAccountNumber: Bool = false
    @Published var validAccountName: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init(ach: ACHStruct  = ACHStruct()) {
        self.ach = ach
        setupValidation()
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
        
    private func setupValidation() {
        // Account Number Validation
        $ach.map(\.accountNumber)
            .removeDuplicates()
            .sink { [weak self] number in
                self?.validAccountNumber = Int(number) != nil && number.count > 3 && number.count < 18
            }
            .store(in: &cancellables)
        
        // Bank Code Validation Validation
        $ach.map(\.bankCode)
            .removeDuplicates()
            .sink { [weak self] bankCode in
                self?.validBankCode = isValidRoutingNumber(code: bankCode)
            }
            .store(in: &cancellables)
        
        // Account Name Validation
        $ach.map(\.name)
            .removeDuplicates()
            .sink { [weak self] name in
                self?.validAccountName = name.isEmpty == false
            }
            .store(in: &cancellables)
        
        // Overall ACH Validation
        Publishers.CombineLatest3($validBankCode, $validAccountName, $validAccountNumber)
            .map { $0 && $1 && $2 }
            .assign(to: &$isValid)
    }
    
    func clear() {
        self.isValid = false
        self.validAccountName = false
        self.validBankCode = false
        self.validAccountNumber = false
        self.ach.clear()
    }
    
}

/// A SwiftUI view that provides a text field for capturing the account name for ACH transactions in Pay Theory payments.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `ACH` environment object to update the account name.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTAchAccountName(placeholder: "Enter Account Holder Name")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTAchAccountName: View {
    /// The environment object that holds the ACH transaction details.
    @EnvironmentObject var account: ACH
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTAchAccountName` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Name on Account".
    public init(placeholder: String = "Name on Account") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `name` property of the `ACH` environment object.
    /// The text field is configured to use word-based autocapitalization.
    public var body: some View {
        TextField(placeholder, text: $account.ach.name)
            .autocapitalization(UITextAutocapitalizationType.words)
    }
}

/// A SwiftUI view that provides a text field for capturing the account number for ACH transactions in Pay Theory payments.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `ACH` environment object to update the account number.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTAchAccountNumber(placeholder: "Enter Account Number")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTAchAccountNumber: View {
    /// The environment object that holds the ACH transaction details.
    @EnvironmentObject var account: ACH
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTAchAccountNumber` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Account Number".
    public init(placeholder: String = "Account Number") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `accountNumber` property of the `ACH` environment object.
    /// The text field is configured to use a decimal pad keyboard and automatically formats the input to a maximum of 17 digits.
    public var body: some View {
        TextField(placeholder, text: $account.ach.accountNumber)
            .onChange(of: account.ach.accountNumber) { newValue in
                account.ach.accountNumber = formatDigitTextField(newValue, maxLength: 17)
            }
            .keyboardType(.decimalPad)
    }
}

/// A SwiftUI view that provides a segmented picker for selecting the ACH account type in Pay Theory payments.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `ACH` environment object to update the account type.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTAchAccountType()
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTAchAccountType: View {
    /// The environment object that holds the ACH transaction details.
    @EnvironmentObject var account: ACH
    
    /// Initializes a new instance of `PTAchAccountType`.
    public init() {}
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a segmented picker that allows selection between different ACH account types.
    /// The picker is bound to the `accountType` property of the `ACH` environment object.
    public var body: some View {
        Picker("Account Type", selection: accountTypeBinding) {
            ForEach(ACHAccountType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    /// A custom binding for the account type.
    ///
    /// This binding ensures that the `accountType` property of the `ACH` environment object
    /// is properly updated and defaults to `.checking` if not set.
    private var accountTypeBinding: Binding<ACHAccountType> {
        Binding<ACHAccountType>(
            get: {
                account.ach.accountType
            },
            set: { newValue in
                account.ach.accountType = newValue
            }
        )
    }
}

/// A SwiftUI view that provides a text field for capturing the routing number for ACH transactions in Pay Theory payments.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `ACH` environment object to update the routing number.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTAchRoutingNumber(placeholder: "Enter Routing Number")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTAchRoutingNumber: View {
    /// The environment object that holds the ACH transaction details.
    @EnvironmentObject var account: ACH
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTAchRoutingNumber` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Routing Number".
    public init(placeholder: String = "Routing Number") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `bankCode` property of the `ACH` environment object.
    /// The text field is configured to use a decimal pad keyboard and automatically formats the input to a maximum of 9 digits.
    public var body: some View {
        TextField(placeholder, text: $account.ach.bankCode)
            .onChange(of: account.ach.bankCode) { newValue in
                account.ach.bankCode = formatDigitTextField(newValue, maxLength: 9)
            }
            .keyboardType(.decimalPad)
    }
}
