//
//  CashFields.swift
//  PayTheory
//
//  Created by Austin Zani on 7/20/21.
//

import SwiftUI
import Combine

struct CashStruct: Encodable {
    var name: String = ""
    var contact: String = ""
    var amount: Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case name = "buyer"
        case contact = "buyer_contact"
        case amount
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(contact, forKey: .contact)
        try container.encode(amount, forKey: .amount)
    }
    
    mutating func clear() {
        name = ""
        contact = ""
        amount = 0
    }

    var validContact: Bool {
        isValidEmail(value: contact) || isValidPhone(value: contact)
    }

    var validName: Bool {
        !name.isEmpty
    }

    var isValid: Bool {
        validContact && validName
    }
}

 class Cash: ObservableObject {
     @Published var cash: CashStruct = .init()
     @Published var isValid: Bool = false
     @Published var validContact: Bool = false
     @Published var validName: Bool = false
     private var cancellables = Set<AnyCancellable>()

    
     init(cash: CashStruct = CashStruct()) {
         self.cash = cash
         setupValidation()
     }
    
     deinit {
         cancellables.forEach { $0.cancel() }
     }
        
     private func setupValidation() {
         // Contact Validation
         $cash.map(\.contact)
             .removeDuplicates()
             .sink { [weak self] contact in
                 let validEmail = isValidEmail(value: contact)
                 let validPhone = isValidPhone(value: contact)
                 self?.validContact = validPhone || validEmail
             }
             .store(in: &cancellables)
        
         // Name Validation
         $cash.map(\.name)
             .removeDuplicates()
             .sink { [weak self] name in
                 self?.validName = !name.isEmpty
             }
             .store(in: &cancellables)
        
         // Overall Card Validation
         Publishers.CombineLatest($validName, $validContact)
             .map { $0 && $1 }
             .assign(to: &$isValid)
     }
    
     func clear() {
         self.isValid = false
         self.validContact = false
         self.validName = false
         self.cash.clear()
     }
 }


/// TextField that can be used to capture the Name for Cash to be used in a Pay Theory barcode creation
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCashName: View {
    @EnvironmentObject var cash: Cash
    let placeholder: String
    
    /// Initializes a new instance of the view with a placeholder text.
    ///
    /// - Parameter placeholder: A `String` for the placeholder text of the text field. Default is "Full Name".
    public init(placeholder: String = "Full Name") {
        self.placeholder = placeholder
    }
    
    public var body: some View {
        TextField(placeholder, text: $cash.cash.name)
            .textInputAutocapitalization(.words)
    }
}

/// TextField that can be used to capture the Contact for Cash to be used in a Pay Theory barcode creation
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCashContact: View {
    @EnvironmentObject var cash: Cash
    let placeholder: String
    
    /// Initializes a new instance of the view with a placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field. The default value is "Phone or Email".
    public init(placeholder: String = "Phone or Email") {
        self.placeholder = placeholder
    }
    
    public var body: some View {
        TextField(placeholder, text: $cash.cash.contact)
    }
}


