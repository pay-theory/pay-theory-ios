//
//  CashValid.swift
//  PayTheory
//
//  Created by Austin Zani on 10/4/24.
//

import SwiftUI
import Combine

// MARK: Main class to track all ACH state

/// Manages the state of a cash transaction.
///
/// This class tracks the validity of the cash transaction details and provides
/// observable properties for the name and contact information.
public class CashState: ObservableObject {
    /// Indicates whether the cash transaction details are valid and ready for processing.
    @Published public private(set) var isValid = false
    /// The state of the cash name.
    @Published public private(set) var name: CashName
    /// The state of the cash contact information.
    @Published public private(set) var contact: CashContact

    
    private var cancellables = Set<AnyCancellable>()
    private var transaction: Transaction
    private var cash: Cash

    var validCashPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(cash.$isValid, transaction.$hostToken)
            .map { valid, hostToken in
                if valid == false || hostToken == nil {
                    return false
                }
                return true
            }
            .eraseToAnyPublisher()
    }

    init(cash: Cash, transaction: Transaction) {
        self.cash = cash
        self.transaction = transaction
        self.name = CashName(cash: cash)
        self.contact = CashContact(cash: cash)

        validCashPublisher.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        name.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        contact.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Classes that require validation on the variable

/// Manages the state of the cash name.
///
/// This class tracks the validity of the cash name and provides an observable property for the name.
public class CashName: ObservableObject, ValidAndEmpty {
    /// Indicates whether the cash name is valid and ready for processing.
    @Published public private(set) var isValid = false
    /// Indicates whether the cash name is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let cash: Cash

    init(cash: Cash) {
        self.cash = cash
        
        cash.$cash.map(\.name)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.isEmpty = value.isEmpty
                self?.isValid = !value.isEmpty
            }
            .store(in: &cancellables)
    }
}

/// Manages the state of the cash contact information.
///
/// This class tracks the validity of the cash contact information and provides
public class CashContact: ObservableObject, ValidAndEmpty {
    /// Indicates whether the cash contact information is valid and ready for processing.
    @Published public private(set) var isValid = false
    /// Indicates whether the cash contact information is empty.
    @Published public private(set) var isEmpty = false
    private var cancellables = Set<AnyCancellable>()

    let cash: Cash

    init(cash: Cash) {
        self.cash = cash

        cash.$validContact.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)

        cash.$cash.map(\.contact)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.isEmpty = value.isEmpty
            }
            .store(in: &cancellables)
    }
}
