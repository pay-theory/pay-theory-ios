//
//  CardState.swift
//  PayTheory
//
//  Created by Austin Zani on 10/4/24.
//
import SwiftUI
import Combine

// MARK: -Main class to track all Card state

/// Manages the state of a credit card transaction, including validation of various card details.
///
/// This class aggregates and tracks the validity of different components of a credit card,
/// such as the card number, expiration date, CVV, and address details.
public class CardState: ObservableObject {
    /// Indicates whether all card details are valid and ready for processing.
    @Published public private(set) var isValid = false
    
    /// The state of the card number.
    @Published public private(set) var number: CardNumber
    
    /// The state of the card expiration date.
    @Published public private(set) var exp: CardExp
    
    /// The state of the card CVV (Card Verification Value).
    @Published public private(set) var cvv: CardCvv
    
    /// The state of the card's associated postal code.
    @Published public private(set) var postalCode: CardPostalCode
    
    /// The state of the cardholder's name.
    @Published public private(set) var name: CardName
    
    /// The state of the first line of the cardholder's address.
    @Published public private(set) var lineOne: CardLineOne
    
    /// The state of the second line of the cardholder's address.
    @Published public private(set) var lineTwo: CardLine2
    
    /// The state of the city in the cardholder's address.
    @Published public private(set) var city: CardCity
    
    /// The state of the region (state/province) in the cardholder's address.
    @Published public private(set) var region: CardRegion
    
    /// The state of the country in the cardholder's address.
    @Published public private(set) var country: CardCountry
    
    private var cancellables = Set<AnyCancellable>()
    private var transaction: Transaction
    private var card: Card
    
    var validCardPublisher: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(card.$isValid, transaction.$hostToken)
            .map { valid, hostToken in
                if valid == false || hostToken == nil {
                    return false
                }
                return true
            }
            .eraseToAnyPublisher()
    }
    
    init(card: Card, transaction: Transaction) {
        self.card = card
        self.number = CardNumber(card: card)
        self.exp = CardExp(card: card)
        self.cvv = CardCvv(card: card)
        self.postalCode = CardPostalCode(card: card)
        self.name = CardName(card: card)
        self.lineOne = CardLineOne(card: card)
        self.lineTwo = CardLine2(card: card)
        self.city = CardCity(card: card)
        self.region = CardRegion(card: card)
        self.country = CardCountry(card: card)
        self.transaction = transaction
        
        validCardPublisher.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        number.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        exp.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        cvv.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        postalCode.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        name.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        lineOne.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        lineTwo.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        city.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        region.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        country.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

    }
    
    deinit {
        cancellables.forEach { $0.cancel()
        }
    }
}


// MARK: - Classes that require validation on the variable

/// Represents and validates the card number for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the card number associated with a credit card transaction.
public class CardNumber: ObservableObject, ValidAndEmpty {
    /// Indicates whether the card number is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    
    /// Indicates whether the card number field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()
    
    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$validCardNumber.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        
        card.$card.map(\.formattedNumber)
            .removeDuplicates()
            .sink { [weak self] number in
                self?.isEmpty = number.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the expiration date for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the expiration date associated with a credit card transaction.
public class CardExp: ObservableObject, ValidAndEmpty {
    /// Indicates whether the expiration date is valid (i.e., not in the past).
    @Published public private(set) var isValid = false
    
    /// Indicates whether the expiration date field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()
    
    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$validExpirationDate.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        
        card.$card.map(\.expirationDate)
            .removeDuplicates()
            .sink { [weak self] number in
                self?.isEmpty = number.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the CVV (Card Verification Value) for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the CVV associated with a credit card transaction.
public class CardCvv: ObservableObject, ValidAndEmpty {
    /// Indicates whether the CVV is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    
    /// Indicates whether the CVV field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()
    
    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$validSecurityCode.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        
        card.$card.map(\.securityCode)
            .removeDuplicates()
            .sink { [weak self] number in
                self?.isEmpty = number.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the postal code for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the postal code associated with a credit card transaction.
public class CardPostalCode: ObservableObject, ValidAndEmpty {
    /// Indicates whether the postal code is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the postal code field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$validPostalCode.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        
        card.$card.map(\.address.postalCode)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Classes that are valid as long as it is not empty

/// Represents and validates the cardholder's name for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the cardholder's name associated with a credit card transaction.
public class CardName: ObservableObject, ValidAndEmpty {
    /// Indicates whether the cardholder's name is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the cardholder's name field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()
    
    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.name)
            .removeDuplicates()
            .sink { [weak self] name in
                self?.isEmpty = name.isEmpty
                self?.isValid = !name.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the first line of the cardholder's address for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
public class CardLineOne: ObservableObject, ValidAndEmpty {
    /// Indicates whether the first line of the cardholder's address is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the first line of the cardholder's address field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.address.line1)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
                self?.isValid = !unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the second line of the cardholder's address for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
public class CardLine2: ObservableObject, ValidAndEmpty {
    /// Indicates whether the second line of the cardholder's address is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the second line of the cardholder's address field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.address.line2)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
                self?.isValid = !unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the city in the cardholder's address for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
public class CardCity: ObservableObject, ValidAndEmpty {
    /// Indicates whether the city in the cardholder's address is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the city in the cardholder's address field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.address.city)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
                self?.isValid = !unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the region (state/province) in the cardholder's address for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
public class CardRegion: ObservableObject, ValidAndEmpty {
    /// Indicates whether the region in the cardholder's address is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the region in the cardholder's address field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.address.region)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
                self?.isValid = !unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

/// Represents and validates the country in the cardholder's address for a credit card transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
public class CardCountry: ObservableObject, ValidAndEmpty {
    /// Indicates whether the country in the cardholder's address is valid according to the card issuer's requirements.
    @Published public private(set) var isValid = false
    /// Indicates whether the country in the cardholder's address field is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let card: Card
    
    init(card: Card) {
        self.card = card
        
        card.$card.map(\.address.country)
            .removeDuplicates()
            .sink { [weak self] number in
                let unwrappedNumber = number ?? ""
                self?.isEmpty = unwrappedNumber.isEmpty
                self?.isValid = !unwrappedNumber.isEmpty
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

