//
//  CardFields.swift
//  PayTheory
//
//  Created by Austin Zani on 3/15/21.
//
import SwiftUI
import Foundation
import Combine

struct CardStruct: Encodable {
    var name: String = ""
    var number: String = ""
    var expirationDate: String = ""
    var securityCode: String = ""
    var address: Address = Address()
    var expirationMonth: String = ""
    var expirationYear: String = ""
    let type = "card"
    var formattedNumber: String = ""
    private enum CodingKeys: String, CodingKey {
        case name
        case number
        case securityCode = "security_code"
        case address
        case expirationMonth = "expiration_month"
        case expirationYear = "expiration_year"
        case type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(number, forKey: .number)
        try container.encode(securityCode, forKey: .securityCode)
        try container.encode(address, forKey: .address)
        try container.encode(expirationMonth, forKey: .expirationMonth)
        try container.encode(expirationYear, forKey: .expirationYear)
        try container.encode(type, forKey: .type)
    }
    
    mutating func clear() {
        self.name = ""
        self.number = ""
        self.formattedNumber = ""
        self.expirationDate = ""
        self.securityCode = ""
        self.address = Address()
        self.expirationMonth = ""
        self.expirationYear = ""
    }
}

class Card: ObservableObject {
    @Published var card: CardStruct
    @Published var isValid: Bool = false
    @Published var validCardNumber = false
    @Published var validExpirationDate = false
    @Published var validSecurityCode = false
    @Published var validPostalCode = false
    private var cancellables = Set<AnyCancellable>()
    
    init(card: CardStruct = CardStruct()) {
        self.card = card
        setupValidation()
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
        
    private func setupValidation() {
        // Card Number Validation
        $card.map(\.formattedNumber)
            .removeDuplicates()
            .sink { [weak self] number in
                self?.validCardNumber = isValidCardNumber(cardString: number)
                self?.card.number = number.replacingOccurrences(of: " ", with: "")
            }
            .store(in: &cancellables)
        
        // Expiration Date Validation
        $card.map(\.expirationDate)
            .removeDuplicates()
            .sink { [weak self] date in
                let (month, year) = splitDate(date)
                self?.validExpirationDate = isValidExpDate(month: month, year: year)
            }
            .store(in: &cancellables)
        
        // Security Code Validation
        $card.map(\.securityCode)
            .removeDuplicates()
            .sink { [weak self] code in
                let num = Int(code)
                self?.validSecurityCode = num != nil && code.length > 2 && code.length < 5
            }
            .store(in: &cancellables)
        
        // Postal Code Validation
        $card.map(\.address.postalCode)
            .removeDuplicates()
            .sink { [weak self] postalCode in
                self?.validPostalCode = isValidPostalCode(value: postalCode ?? "")
            }
            .store(in: &cancellables)
        
        // Overall Card Validation
        Publishers.CombineLatest4($validCardNumber, $validExpirationDate, $validSecurityCode, $validPostalCode)
            .map { $0 && $1 && $2 && $3 }
            .assign(to: &$isValid)
    }
    
    func clear() {
        self.isValid = false
        self.validCardNumber = false
        self.validExpirationDate = false
        self.validSecurityCode = false
        self.validPostalCode = false
        self.card.clear()
    }
}

/// A SwiftUI view that provides a text field for capturing the cardholder's name for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the cardholder's name.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardName(placeholder: "Enter Cardholder Name")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardName: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String

    /// Initializes a new instance of `PTCardName` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Name on Card".
    public init(placeholder: String = "Name on Card") {
        self.placeholder = placeholder
    }

    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `name` property of the `Card` environment object.
    /// The text field is configured to use word-based autocapitalization.
    public var body: some View {
        TextField(placeholder, text: $card.card.name)
            .textInputAutocapitalization(.words)
    }
}

/// A SwiftUI view that provides a text field for capturing the card number for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the card number.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
/// - Important: This field is required to be able to run a transaction.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardNumber(placeholder: "Enter Card Number")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardNumber: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardNumber` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Card Number".
    public init(placeholder: String = "Card Number") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `formattedNumber` property of the `Card` environment object.
    /// The text field is configured to use a decimal pad keyboard and automatically formats the input as a credit card number.
    public var body: some View {
        TextField(placeholder, text: $card.card.formattedNumber)
            .onChange(of: card.card.formattedNumber) { newValue in
                let strippedNumber = newValue.filter({$0.isNumber})
                card.card.formattedNumber = insertCreditCardSpaces(strippedNumber)
                card.card.number = strippedNumber
            }
            .keyboardType(.decimalPad)
    }
}

/// A SwiftUI view that provides a text field for capturing the expiration date for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the expiration date.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
/// - Important: This field is required to be able to run a transaction.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTExp(placeholder: "MM/YY")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTExp: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTExp` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "MM/YY".
    public init(placeholder: String = "MM/YY") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `expirationDate` property of the `Card` environment object.
    /// The text field is configured to use a decimal pad keyboard and automatically formats the input as an expiration date.
    public var body: some View {
        TextField(placeholder, text: $card.card.expirationDate)
            .onChange(of: card.card.expirationDate) { newValue in
                let formattedExp = formatExpirationDate(newValue)
                card.card.expirationDate = formattedExp
                let (month, year) = splitDate(formattedExp)
                card.card.expirationMonth = month
                card.card.expirationYear = year
            }
            .keyboardType(.decimalPad)
    }
}

/// A SwiftUI view that provides a text field for capturing the CVV (Card Verification Value) for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the CVV.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
/// - Important: This field is required to be able to run a transaction.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCvv(placeholder: "Enter CVV")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCvv: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCvv` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "CVV".
    public init(placeholder: String = "CVV") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `securityCode` property of the `Card` environment object.
    /// The text field is configured to use a decimal pad keyboard and automatically formats the input to a maximum of 4 digits.
    public var body: some View {
        TextField(placeholder, text: $card.card.securityCode)
            .onChange(of: card.card.securityCode) { newValue in
                card.card.securityCode = formatDigitTextField(newValue, maxLength: 4)
            }
            .keyboardType(.decimalPad)
    }
}

/// A SwiftUI view that provides a text field for capturing the first line of the address for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the address line 1.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardLineOne(placeholder: "Street Address")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardLineOne: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardLineOne` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Address Line 1".
    public init(placeholder: String = "Address Line 1") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `line1` property of the `Card` environment object's address.
    /// The text field is configured to use word-based autocapitalization.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.line1 ?? "")
            .autocapitalization(UITextAutocapitalizationType.words)
    }
}

/// A SwiftUI view that provides a text field for capturing the second line of the address for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the address line 2.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardLineTwo(placeholder: "Apartment, suite, etc.")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardLineTwo: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardLineTwo` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Address Line 2".
    public init(placeholder: String = "Address Line 2") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `line2` property of the `Card` environment object's address.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.line2 ?? "")
    }
}

/// A SwiftUI view that provides a text field for capturing the city for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the city.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardCity(placeholder: "Enter City")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardCity: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardCity` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "City".
    public init(placeholder: String = "City") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `city` property of the `Card` environment object's address.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.city ?? "")
    }
}

/// A SwiftUI view that provides a text field for capturing the region (state/province) for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the region.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardRegion(placeholder: "State/Province")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardRegion: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardRegion` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Region".
    public init(placeholder: String = "Region") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `region` property of the `Card` environment object's address.
    /// The text field is configured to use all-caps autocapitalization and disable autocorrection.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.region ?? "")
            .autocapitalization(UITextAutocapitalizationType.allCharacters)
            .disableAutocorrection(true)
    }
}

/// A SwiftUI view that provides a text field for capturing the postal code for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the postal code.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardPostalCode(placeholder: "ZIP/Postal Code")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardPostalCode: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardPostalCode` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Postal Code".
    public init(placeholder: String = "Postal Code") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `postalCode` property of the `Card` environment object's address.
    /// The text field is configured to use a numbers and punctuation keyboard.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.postalCode ?? "")
            .keyboardType(.numbersAndPunctuation)
    }
}

/// A SwiftUI view that provides a text field for capturing the country for card payments in Pay Theory.
///
/// This view is designed to be used within a Pay Theory form and requires an ancestor view to be wrapped in a `PTForm`.
/// It automatically binds to the `Card` environment object to update the country.
///
/// - Note: This view must be used within a view hierarchy that includes a `PTForm` as an ancestor.
///
/// Example usage:
/// ```swift
/// PTForm {
///     PTCardCountry(placeholder: "Country")
///     // Other Pay Theory form fields...
/// }
/// ```
public struct PTCardCountry: View {
    /// The environment object that holds the card payment details.
    @EnvironmentObject var card: Card
    
    /// The placeholder text displayed in the text field when it's empty.
    let placeholder: String
    
    /// Initializes a new instance of `PTCardCountry` with a custom placeholder text.
    ///
    /// - Parameter placeholder: A `String` that represents the placeholder text for the text field.
    ///   The default value is "Country".
    public init(placeholder: String = "Country") {
        self.placeholder = placeholder
    }
    
    /// The body of the view, defining its content and behavior.
    ///
    /// This view presents a `TextField` that is bound to the `country` property of the `Card` environment object's address.
    public var body: some View {
        TextField(placeholder, text: $card.card.address.country ?? "")
    }
}
