//
//  ACHValid.swift
//  PayTheory
//
//  Created by Austin Zani on 10/4/24.
//

import SwiftUI
import Combine

// MARK: - Main class to track all ACH state

/// Manages the state of an ACH (Automated Clearing House) transaction.
///
/// This class tracks the validity of the ACH transaction details and provides
/// observable properties for the account name, account number, and routing number.
public class ACHState: ObservableObject {
    /// Indicates whether the ACH transaction details are valid and ready for processing.
    @Published public private(set) var isValid = false
    
    /// The state of the ACH account name.
    @Published public private(set) var accountName: ACHAccountName
    
    /// The state of the ACH account number.
    @Published public private(set) var accountNumber: ACHAccountNumber
    
    /// The state of the ACH routing number.
    @Published public private(set) var routingNumber: ACHRoutingNumber
    
    private var ach: ACH
    private var transaction: Transaction
    private var cancellables = Set<AnyCancellable>()

    var validACHPublisher: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(ach.$isValid, transaction.$hostToken)
            .map { valid, hostToken in
                if valid == false || hostToken == nil {
                    return false
                }
                return true
            }
            .eraseToAnyPublisher()
    }

    init(ach: ACH, transaction: Transaction) {
        self.ach = ach
        self.transaction = transaction
        self.accountName = ACHAccountName(bank: ach)
        self.accountNumber = ACHAccountNumber(bank: ach)
        self.routingNumber = ACHRoutingNumber(bank: ach)

        validACHPublisher.sink { valid in
            self.isValid = valid
        }
        .store(in: &cancellables)
        accountName.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        accountNumber.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        routingNumber.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}


// MARK: - Classes that require validation on the variable

/// Represents and validates the account name for an ACH transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the account name associated with an ACH transaction.
public class ACHAccountName: ObservableObject, ValidAndEmpty {
    @ObservedObject private var bank: ACH

    /// Indicates whether the account name is valid according to the ACH requirements.
    public var isValid: Bool {
        bank.validAccountName
    }
    
    /// Indicates whether the account name is empty.
    public var isEmpty: Bool {
        bank.ach.name.isEmpty
    }
    
    init(bank: ACH) {
        self._bank = ObservedObject(wrappedValue: bank)
    }
}

/// Represents and validates the account number for an ACH transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the account number associated with an ACH transaction.
public class ACHAccountNumber: ObservableObject, ValidAndEmpty {
    @ObservedObject private var bank: ACH

    /// Indicates whether the account number is valid according to the ACH requirements.
    public var isValid: Bool {
        bank.validAccountNumber
    }
    
    /// Indicates whether the account number is empty.
    public var isEmpty: Bool {
        bank.ach.accountNumber.isEmpty
    }
    
    init(bank: ACH) {
        self._bank = ObservedObject(wrappedValue: bank)
    }
}

/// Represents and validates the routing number for an ACH transaction.
///
/// This class conforms to `ValidAndEmpty`, providing validation and emptiness checks
/// for the routing number associated with an ACH transaction.
public class ACHRoutingNumber: ObservableObject, ValidAndEmpty {
    @ObservedObject private var bank: ACH

    /// Indicates whether the routing number is valid according to the ACH requirements.
    public var isValid: Bool {
        bank.validBankCode
    }
    
    /// Indicates whether the routing number is empty.
    public var isEmpty: Bool {
        bank.ach.bankCode.isEmpty
    }
    
    init(bank: ACH) {
        self._bank = ObservedObject(wrappedValue: bank)
    }
}
