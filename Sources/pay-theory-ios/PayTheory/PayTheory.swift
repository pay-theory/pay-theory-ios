//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//
// Base of the Pay Theory class that contains all attributes, the initializer, and the functions needed to make it conform to the WebSocketProtocol

import SwiftUI
import Foundation
import Combine
import DeviceCheck

/// A class that manages payment processing through the Pay Theory service.
///
/// The `PayTheory` class provides a comprehensive interface for handling various payment methods,
/// including card payments, ACH transfers, and cash transactions. It manages the state of each
/// payment method, calculates service fees, and handles communication with the Pay Theory servers.
///
/// This class conforms to `ObservableObject`, allowing SwiftUI views to react to changes in its state,
/// and `WebSocketProtocol` for handling real-time communication with the Pay Theory service.
///
/// - Important: Always check the `isReady` property before attempting to process payments to ensure
///   the instance has completed initialization.
///
/// - Note: This class uses combine framework for reactive programming and DeviceCheck for secure device attestation.
public class PayTheory: ObservableObject, WebSocketProtocol {
    // Internal State variables to track state with the fields
    var envCard: Card
    var envPayor: Payor
    var envAch: ACH
    var envCash: Cash
    var cancellables = Set<AnyCancellable>()
    
    // Public State Variables
    /// The current state of the card payment method.
    ///
    /// This property provides access to the current state of the card payment method,
    /// including validation status and any entered card details.
    @Published internal(set) public var card: CardState

    /// The current state of the cash payment method.
    ///
    /// This property provides access to the current state of the cash payment method,
    /// including any relevant details for cash transactions.
    @Published internal(set) public var cash: CashState

    /// The current state of the ACH (Automated Clearing House) payment method.
    ///
    /// This property provides access to the current state of the ACH payment method,
    /// including validation status and any entered bank account details.
    @Published internal(set) public var ach: ACHState

    /// The calculated service fee for card transactions, if applicable.
    ///
    /// This property holds the service fee amount (in cents) for card transactions.
    /// It will be `nil` if no fee applies or if the fee hasn't been calculated yet.
    @Published internal(set) public var cardServiceFee: Int?

    /// The calculated service fee for bank (ACH) transactions, if applicable.
    ///
    /// This property holds the service fee amount (in cents) for bank transactions.
    /// It will be `nil` if no fee applies or if the fee hasn't been calculated yet.
    @Published internal(set) public var bankServiceFee: Int?

    /// Indicates whether the PayTheory instance is ready for use.
    ///
    /// This property becomes `true` when the instance has completed its initialization
    /// and is ready to process payments. It should be checked before attempting to use
    /// the instance for payment operations.
    @Published internal(set) public var isReady: Bool = false

    var isAwaitingResponse: Bool = false
    let service = DCAppAttestService.shared
    var amount: Int?
    var apiKey: String
    var environment: String
    var stage: String
    var monitor: NetworkMonitor
    var sessionId = generateUUID()
    @ObservedObject var transaction: Transaction
    var transactionCancellable: AnyCancellable? = nil
    public var errorHandler: (PTError) -> Void
    
    var appleEnvironment: String
    var devMode = false
    var isInitialized = false
    var isComplete = false
    var passedPayor: Payor?
    var ptToken: String?
    var country: String?
    var currency: String?
    var creditCardFeeModel: ServiceFeeModel?
    var debitCardFeeModel: ServiceFeeModel?
    var hostTokenTimestamp: Date?
    var session: WebSocketSession
    // Attestation string being set should trigger the connection of our socket or sending of the hostTokenMessage if it is already connected
    var attestationString: String?
    var applePayHandler: PayTheoryApplePayHandler
    var isConnecting = false
    
    // Setting of the cardBin should trigger the potential calculation of fees if an amount is set
    var cardBin: String? {
        didSet {
            // If there is a cardBin then try and send the amount message if the amount is sent
            if let cardBin = cardBin {
                if let _ = amount {
                    Task {
                        await sendCalcFeeMessage(cardBin: cardBin)
                    }
                }
            } else { // If cardBin is set to nil then set the cardServiceFee to nil
                self.cardServiceFee = nil
            }
        }
    }
    
    /// Initializes a new instance of the PayTheory class.
    ///
    /// This initializer sets up the PayTheory instance with the provided parameters and prepares
    /// it for payment processing. It configures the network monitor, sets up observers for app
    /// lifecycle events, and initializes the necessary state for various payment methods.
    ///
    /// - Parameters:
    ///   - amount: An optional integer representing the transaction amount in cents.
    ///             This will be used to calculate fees if you are using the Service Fee mode.
    ///             If not provided, fees won't be calculated automatically.
    ///   - apiKey: A string containing the API key for authentication with the Pay Theory service.
    ///             This should be in the format '{partner}-{paytheorystage}-{UUID}'.
    ///   - devMode: A boolean flag indicating whether to run in development mode. Defaults to `false`.
    ///              When `true`, it uses the development environment for app attestation.
    ///   - errorHandler: A closure that handles any errors that might occur during initialization
    ///                   and other background actions. It takes a `PTError` parameter.
    ///
    /// - Throws: A fatal error if the provided API key is not in the correct format.
    ///
    /// - Important: The `isReady` property will be set to `true` when the instance has completed
    ///              initialization and is ready for use. Always check this before proceeding with
    ///              payment operations.
    ///
    /// - Note: This initializer sets up various state variables and configures the instance
    ///         based on the provided API key. It also sets up Combine publishers to propagate
    ///         changes in the instance's state.
    public init(amount: Int? = nil, apiKey: String, devMode: Bool = false,  errorHandler: @escaping (PTError) -> Void) {
        // Parse the API key to extract environment and stage information
        var apiParts = apiKey.split {$0 == "-"}.map { String($0) }
        // Validate the the API key is the correct format
        if apiParts.count != 3 {
            debugPrint("This is not a valid API Key. API Key should be formatted '{partner}-{paytheorystage}-{UUID}'")
            apiParts = ["", ""]
        }
        
        self.amount = amount
        self.apiKey = apiKey
        environment = apiParts[0]
        stage = apiParts[1]
        appleEnvironment = stage == "paytheory" ? "appattest" : "appattestdevelop"
        self.devMode = devMode
        
        // Store the completion handler
        self.errorHandler = errorHandler
        
        // Initialize payment method objects
        envAch = ACH()
        envCard = Card()
        envPayor = Payor()
        envCash = Cash()
        
        // Set up network monitoring
        monitor = NetworkMonitor()
        
        // Initialize transaction object
        let newTransaction = Transaction(apiKey: apiKey)
        transaction = newTransaction
        
        // Initialize validation objects
        ach = ACHState(ach: envAch, transaction: newTransaction)
        card = CardState(card: envCard, transaction: newTransaction)
        cash = CashState(cash: envCash, transaction: newTransaction)
        
        // Initialize the WebSocketSession we will use for socket communications
        let provider = WebSocketProvider()
        session = WebSocketSession()
        applePayHandler = PayTheoryApplePayHandler()
        applePayHandler.setPayTheory(self)
        session.prepare(_provider: provider, _handler: self)
        
        // Set up Combine publishers to propagate changes
        envAch.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        envCard.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        envCash.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        transaction.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        ach.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        card.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        cash.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        envCard.$card.map(\.number)
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] number in
                self?.cardNumberChanged(number)
            }
            .store(in: &cancellables)
            
        // Initialize websocket connection
        Task {
            do {
                _ = try await ensureConnected()
            } catch {
                _ = handleConnectionError(error)
            }
        }
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Functions used to conform to the WebSocketProtocol
    func receiveMessage(message: String) {
        onMessage(response: message)
    }
    
    func handleError(error: Error) {
        errorHandler(PTError(code: .socketError, error: "An unknown socket error occured"))
    }
    
    func handleDisconnect() {
        DispatchQueue.main.async {
            self.transaction.sessionKey = nil
            self.transaction.publicKey = nil
        }
        setReady(false)
    }
}
