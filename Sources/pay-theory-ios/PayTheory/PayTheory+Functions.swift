//
//  PayTheory+Public.swift
//  PayTheory
//
//  Created by Austin Zani on 8/7/24.
//
// Extension of the Pay Theory class that contains public functions that are available to users of the PayTheory SDK

import Foundation

extension PayTheory {
    // MARK: - Tokenize Payment Method
    
    /// Tokenizes a payment method asynchronously.
    ///
    /// This function tokenizes a payment method based on the provided parameters. It supports card and ACH payment methods.
    ///
    /// - Parameters:
    ///   - paymentMethod: The type of payment method to tokenize (e.g., `.CARD` or `.ACH`).
    ///   - payor: An optional `Payor` object representing the payer. If nil, `envPayor` will be used.
    ///   - payorId: An optional string representing the payer's ID.
    ///   - metadata: An optional dictionary of additional metadata to include with the tokenization.
    ///
    /// - Returns: A TokenizePaymentMethodResponse with all possible responses.
    ///
    /// - Important: This function requires an active WebSocket connection. It will attempt to establish a connection if one doesn't exist.
    public func tokenizePaymentMethod(paymentMethod: PaymentType,
                                      payor: Payor? = nil,
                                      payorId: String? = nil,
                                      metadata: [String: String]? = nil) async -> TokenizePaymentMethodResponse {
        // Check if the action can be called
        if let error = canCallAction() {
            return .error(error)
        }
        isInitialized = true
        
        // Ensure WebSocket connection
        do {
            _ = try await ensureConnected()
            // If the
            if self.hostTokenStillValid() == false {
                try await fetchToken()
                try await sendHostTokenMessage(calcFees: false)
            }
        } catch {
            let connectionError = handleConnectionError(error, sendToErrorHandler: false)
            isInitialized = false
            return .error(connectionError)
        }
        
        // Set transaction properties
        self.transaction.payor = payor ?? envPayor
        self.transaction.metadata = metadata ?? [:]
        
        // Prepare the message body based on the payment method
        let body: String?
        switch paymentMethod {
        case .card where envCard.isValid:
            body = transaction.createTokenizePaymentMethodBody(instrument: .card(envCard.card), payorId: payorId)
        case .ach where envAch.isValid:
            body = transaction.createTokenizePaymentMethodBody(instrument: .ach(envAch.ach), payorId: payorId)
        case .cash:
            isInitialized = false
            return .error(PTError(code: .noFields,
                                  error: "Cash payment methods are not able to be tokenized"))
        default:
            isInitialized = false
            return .error(PTError(code: .notValid,
                                  error: "\(paymentMethod.rawValue) is missing valid details to proceed."))
        }
        
        guard let messageBody = body else {
            return .error(PTError(code: .invalidParam, error: "Unable to create message body"))
        }
        
        // Send the message and wait for response
        do {
            let response = try await session.sendMessageAndWaitForResponse(messageBody: messageBody)
            isInitialized = false
            return parseTokenizeResponse(response)
        } catch {
            return .error(PTError(code: .socketError, error: "There was an error sending the message to the server."))
        }
    }
    
    /// Tokenizes a payment method using a completion handler.
    ///
    /// This function provides a closure-based alternative to the async `tokenizePaymentMethod` function.
    /// It internally calls the async version and delivers the result through a completion handler.
    ///
    /// - Parameters:
    ///   - paymentMethod: The type of payment method to tokenize (e.g., `.CARD` or `.ACH`).
    ///   - payor: An optional `Payor` object representing the payer. If nil, `envPayor` will be used.
    ///   - payorId: An optional string representing the payer's ID.
    ///   - metadata: An optional dictionary of additional metadata to include with the tokenization.
    ///   - completion: A closure that will be called with the result of the tokenization.
    ///     The closure takes a `Result<String, Error>` parameter, where the success case contains
    ///     the tokenized payment method as a string, and the failure case contains any error that occurred.
    ///
    /// - Important: This function executes asynchronously. The completion handler will be called on an arbitrary thread.
    public func tokenizePaymentMethod(paymentMethod: PaymentType,
                                      payor: Payor? = nil,
                                      payorId: String? = nil,
                                      metadata: [String: String]? = nil,
                                      completion: @escaping (TokenizePaymentMethodResponse) -> Void) {
        Task {
            let result = await tokenizePaymentMethod(paymentMethod: paymentMethod,
                                                     payor: payor,
                                                     payorId: payorId,
                                                     metadata: metadata)
            
            completion(result)
        }
    }
    
    // MARK: - Transact
    
    /// Processes a transaction asynchronously.
    ///
    /// This function initiates a transaction based on the provided parameters. It supports various payment methods
    /// including card, ACH, and cash.
    ///
    /// - Parameters:
    ///   - amount: The amount to be transacted in cents.
    ///   - paymentMethod: The type of payment method to use for the transaction.
    ///   - accountCode: An optional account code associated with the transaction.
    ///   - fee: An optional fee amount in cents. Must be provided if `feeMode` is set to `.SERVICE_FEE`.
    ///   - feeMode: The mode of the fee, either `.MERCHANT_FEE` or `.SERVICE_FEE`. Defaults to `.MERCHANT_FEE`.
    ///   - healthExpenseType: An optional health expense type.
    ///   - invoiceId: An optional invoice ID.
    ///   - level3DataSummary: An optional summary of level 3 data.
    ///   - metadata: An optional dictionary of additional metadata.
    ///   - oneTimeUseToken: A boolean indicating whether a one-time use token is used.
    ///   - payor: An optional payor object. Defaults to `envPayor` if not provided.
    ///   - payorId: An optional payor ID.
    ///   - receiptDescription: An optional description for the receipt.
    ///   - recurringId: An optional recurring ID.
    ///   - reference: An optional reference string.
    ///   - sendReceipt: A boolean indicating whether to send a receipt.
    ///
    /// - Returns: A string representing the response from the transaction.
    ///
    /// - Throws: A `PTError` if the transaction process fails or if invalid parameters are provided.
    ///
    /// - Important: This function requires an active WebSocket connection. It will attempt to establish a connection if one doesn't exist.
    public func transact(amount: Int,
                         paymentMethod: PaymentType,
                         accountCode: String? = nil,
                         fee: Int? = nil,
                         feeMode: FeeMode = .merchantFee,
                         healthExpenseType: HealthExpenseType? = nil,
                         invoiceId: String? = nil,
                         level3DataSummary: Level3DataSummary? = nil,
                         metadata: [String: String]? = nil,
                         oneTimeUseToken: Bool = false,
                         payor: Payor? = nil,
                         payorId: String? = nil,
                         receiptDescription: String? = nil,
                         recurringId: String? = nil,
                         reference: String? = nil,
                         sendReceipt: Bool = false) async -> TransactResponse {
        // Check if the action can be called
        if let error = canCallAction() {
            return .error(error)
        }
        isInitialized = true
        
        // Ensure WebSocket connection
        do {
            _ = try await ensureConnected()
            if self.hostTokenStillValid() == false {
                try await fetchToken()
                try await sendHostTokenMessage(calcFees: false)
            }
        } catch {
            let connectionError = handleConnectionError(error, sendToErrorHandler: false)
            isInitialized = false
            return .error(connectionError)
        }
        
        // Set transaction properties
        self.transaction.amount = amount
        self.transaction.payor = payor ?? envPayor
        self.transaction.feeMode = feeMode
        self.transaction.metadata = metadata ?? [:]
        
        // Validate fee for SERVICE_FEE mode
        if fee == nil && feeMode == .serviceFee {
            isInitialized = false
            return .error(PTError(code: .invalidParam,
                                  error: "Fee must be passed in if you are using the Service Fee fee mode"))
        }
        
        // Prepare PayTheoryData
        let payTheoryData = PayTheoryData(accountCode: accountCode,
                                          fee: fee,
                                          healthExpenseType: healthExpenseType,
                                          invoiceId: invoiceId,
                                          level3DataSummary: level3DataSummary,
                                          oneTimeUseToken: oneTimeUseToken,
                                          payorId: payorId,
                                          receiptDescription: receiptDescription,
                                          recurringId: recurringId,
                                          reference: reference,
                                          sendReceipt: sendReceipt,
                                          metadata: metadata)
        
        // Prepare the message body based on the payment method
        let body: String?
        switch paymentMethod {
        case .card where envCard.isValid:
            body = transaction.createTransferPartOneBody(instrument: .card(envCard.card), payTheoryData: payTheoryData)
        case .ach where envAch.isValid:
            body = transaction.createTransferPartOneBody(instrument: .ach(envAch.ach), payTheoryData: payTheoryData)
        case .cash where envCash.isValid:
            envCash.cash.amount = amount
            body = transaction.createCashBody(cash: envCash.cash, payTheoryData: payTheoryData)
        default:
            isInitialized = false
            return .error(PTError(code: .notValid, error: "\(paymentMethod.rawValue) is missing valid details to proceed."))
        }
        
        guard let messageBody = body else {
            return .error(PTError(code: .invalidParam, error: "Unable to create message body"))
        }
        
        // Send the message and wait for response
        do {
            let response = try await session.sendMessageAndWaitForResponse(messageBody: messageBody)
            isInitialized = false
            return parseTransactResponse(response)
        } catch {
            return .error(PTError(code: .socketError, error: "There was an error sending the message to the server."))
        }
    }
    
    /// Processes a transaction using a completion handler.
    ///
    /// This function provides a closure-based alternative to the async `transact` function.
    /// It internally calls the async version and delivers the result through a completion handler.
    ///
    /// - Parameters:
    ///   - amount: The amount to be transacted in cents.
    ///   - paymentMethod: The type of payment method to use for the transaction.
    ///   - accountCode: An optional account code associated with the transaction.
    ///   - fee: An optional fee amount in cents. Must be provided if `feeMode` is set to `.SERVICE_FEE`.
    ///   - feeMode: The mode of the fee, either `.MERCHANT_FEE` or `.SERVICE_FEE`. Defaults to `.MERCHANT_FEE`.
    ///   - healthExpenseType: An optional health expense type.
    ///   - invoiceId: An optional invoice ID.
    ///   - level3DataSummary: An optional summary of level 3 data.
    ///   - metadata: An optional dictionary of additional metadata.
    ///   - oneTimeUseToken: A boolean indicating whether a one-time use token is used.
    ///   - payor: An optional payor object. Defaults to `envPayor` if not provided.
    ///   - payorId: An optional payor ID.
    ///   - receiptDescription: An optional description for the receipt.
    ///   - recurringId: An optional recurring ID.
    ///   - reference: An optional reference string.
    ///   - sendReceipt: A boolean indicating whether to send a receipt.
    ///   - completion: A closure that will be called with the result of the transaction.
    ///     The closure takes a `Result<String, Error>` parameter, where the success case contains
    ///     the response from the transaction as a string, and the failure case contains any error that occurred.
    ///
    /// - Important: This function executes asynchronously. The completion handler will be called on an arbitrary thread.
    public func transact(amount: Int,
                         paymentMethod: PaymentType,
                         accountCode: String? = nil,
                         fee: Int? = nil,
                         feeMode: FeeMode = .merchantFee,
                         healthExpenseType: HealthExpenseType? = nil,
                         invoiceId: String? = nil,
                         level3DataSummary: Level3DataSummary? = nil,
                         metadata: [String: String]? = nil,
                         oneTimeUseToken: Bool = false,
                         payor: Payor? = nil,
                         payorId: String? = nil,
                         receiptDescription: String? = nil,
                         recurringId: String? = nil,
                         reference: String? = nil,
                         sendReceipt: Bool = false,
                         completion: @escaping (TransactResponse) -> Void) {
        Task {
            let result = await transact(amount: amount,
                                            paymentMethod: paymentMethod,
                                            accountCode: accountCode,
                                            fee: fee,
                                            feeMode: feeMode,
                                            healthExpenseType: healthExpenseType,
                                            invoiceId: invoiceId,
                                            level3DataSummary: level3DataSummary,
                                            metadata: metadata,
                                            oneTimeUseToken: oneTimeUseToken,
                                            payor: payor,
                                            payorId: payorId,
                                            receiptDescription: receiptDescription,
                                            recurringId: recurringId,
                                            reference: reference,
                                            sendReceipt: sendReceipt)
            completion(result)
        }
    }
    
    // MARK: - Helper Functions to resdet the PayTheory object or the Amount for calculating fees
    
    /// Resets the environment objects used by Pay Theory Fields.
    ///
    /// This function clears all payment information and prepares the environment for a new payment transaction.
    /// It performs the following actions:
    /// - Clears ACH, Card, Payor, and Cash environment objects
    /// - Resets the transaction details
    /// - Generates a new session ID
    /// - Attempts to reconnect and fetch a new token
    ///
    /// - Important: This function should be called when you want to start a fresh payment process and clear all data in the hosted fields.
    public func resetPT() {
        self.envAch.clear()
        self.envCard.clear()
        self.envPayor.clear()
        self.envCash.clear()
        self.transaction.resetTransaction()
        self.sessionId = generateUUID()
        self.isComplete = false
        self.isInitialized = false
        Task {
            do {
                let connected = try await ensureConnected()
                if connected {
                    try await fetchToken()
                    try await sendHostTokenMessage()
                }
            } catch {
                _ = handleConnectionError(error)
            }
        }
    }
    
    /// Updates the stored amount with a new value and recalculates fees if necessary.
    ///
    /// This function checks if the new amount is different from the currently stored amount.
    /// If it is different, it updates the stored amount and triggers a recalculation of fees.
    /// This approach prevents unnecessary fee recalculations when the amount hasn't changed.
    ///
    /// - Parameter newAmount: The new amount to be set.
    ///
    /// - Note: This function will only update the amount and recalculate fees if `newAmount` is different from the current `amount`.
    public func updateAmount(newAmount: Int) {
        // Only set the amount if it is different than what is stored
        // We don't want to recalc the fees for the same amount
        if amount != newAmount {
            amount = newAmount
            calcFeesWithAmount()
        }
    }
}
