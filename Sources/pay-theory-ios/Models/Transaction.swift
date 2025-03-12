//
//  Transaction.swift
//  PayTheory
//
//  Created by Austin Zani on 3/29/21.
//

import Foundation
import Sodium

/// A class representing a transaction in the PayTheory system.
///
/// This class handles the encryption, decryption, and creation of various transaction-related messages.
class Transaction: ObservableObject {
    /// The host token for the transaction.
    @Published var hostToken: String?
    
    /// The session key for the transaction.
    var sessionKey: String?
    
    /// The public key used for encryption.
    var publicKey: Bytes?
    
    /// The PayTheory instrument identifier.
    var ptInstrument: String?
    
    /// The API key for PayTheory.
    var apiKey: String
    
    /// The amount of the transaction in cents.
    var amount: Int = 0
    
    /// The key pair used for encryption and decryption.
    var keyPair: Box.KeyPair
    
    /// The Sodium instance used for cryptographic operations.
    var sodium: Sodium
    
    /// The fee mode for the transaction.
    var feeMode: FeeMode = .merchantFee
    
    /// Additional metadata for the transaction.
    var metadata: [String: String] = [:]
    
    /// The payor information for the transaction.
    var payor: Payor?
    
    /// Indicates whether confirmation is required for the transaction.
    var confirmation: Bool = false
    
    /// Initializes a new Transaction instance.
    /// - Parameter apiKey: The API key for PayTheory.
    init(apiKey: String) {
        self.apiKey = apiKey
        sodium = Sodium()
        keyPair = sodium.box.keyPair()!
    }
    
    /// Encrypts a message body for secure transmission.
    /// - Parameters:
    ///   - string: The message to encrypt.
    ///   - action: The action associated with the message.
    /// - Returns: The encrypted message as a JSON string.
    func encryptBody(string: String, action: String) -> String {
        var message: [String: Any] = [:]
        let byteString = string.bytes
        let encryptedMessage: Bytes =
            sodium.box.seal(message: byteString,
                            recipientPublicKey: publicKey!,
                            senderSecretKey: self.keyPair.secretKey)!

        message["encoded"] = convertBytesToString(bytes: encryptedMessage)
        message["sessionKey"] = sessionKey
        message["publicKey"] = convertBytesToString(bytes: self.keyPair.publicKey)
        message["action"] =  action
        return stringify(jsonDictionary: message)
    }

    /// Decrypts a received message body.
    /// - Parameters:
    ///   - body: The encrypted message body.
    ///   - publicKey: The public key of the sender.
    /// - Returns: The decrypted message as a string.
    func decryptBody(body: String, publicKey: String) -> String {
        let senderKey = convertStringToByte(string: publicKey)
        let bodyBytes = convertStringToByte(string: body)
        if let decrypted = sodium.box.open(nonceAndAuthenticatedCipherText: bodyBytes,
                                           senderPublicKey: senderKey,
                                           recipientSecretKey: self.keyPair.secretKey) {
            let decryptedString = convertBytesToString(bytes: decrypted)
            let decodedData = Data(base64Encoded: decryptedString) ?? Data()
            let decodedString = String(data: decodedData, encoding: .utf8) ?? ""
            return decodedString
        }
        return ""
    }
    
    /// Creates an encrypted body for a cash payment.
    /// - Parameters:
    ///   - cash: The cash payment structure.
    ///   - payTheoryData: Additional PayTheory-specific data.
    /// - Returns: An encrypted JSON string representing the cash payment data, or nil if the host token is not set.
    func createCashBody(cash: CashStruct, payTheoryData: PayTheoryData) -> String? {
        if let hostToken = hostToken {
            let body = CashPaymentData(
                hostToken: hostToken,
                sessionKey: sessionKey ?? "",
                timing: Date().millisecondsSince1970,
                payorInfo: payor,
                payTheoryData: payTheoryData,
                metadata: metadata,
                payment: cash)
            let bodyString = convertToJSONString(body)
            return encryptBody(string: bodyString, action: barcodeMessage)
        } else {
            return nil
        }
    }
    
    /// Creates an encrypted body for the first part of a transfer payment.
    /// - Parameters:
    ///   - instrument: The payment method data.
    ///   - payTheoryData: Additional PayTheory-specific data.
    /// - Returns: An encrypted JSON string representing the transfer payment data, or nil if the host token is not set.
    func createTransferPartOneBody(instrument: PaymentMethodData, payTheoryData: PayTheoryData) -> String? {
        if let hostToken = hostToken {
            let paymentData = PaymentData(feeMode: feeMode, currency: "USD", amount: amount)
            let body = TransferPartOneData(hostToken: hostToken,
                                           sessionKey: sessionKey ?? "",
                                           timing: Date().millisecondsSince1970,
                                           payorInfo: payor,
                                           payTheoryData: payTheoryData,
                                           metadata: metadata,
                                           paymentMethodData: instrument,
                                           paymentData: paymentData,
                                           confirmationNeeded: false)
            let bodyString = convertToJSONString(body)
            return encryptBody(string: bodyString, action: transferMessage)
        } else {
            return nil
        }
    }
    
    /// Creates an encrypted body for tokenizing a payment method.
    /// - Parameters:
    ///   - instrument: The payment method data to be tokenized.
    ///   - payorId: Optional payor ID.
    /// - Returns: An encrypted JSON string representing the tokenization request, or nil if the host token is not set.
    func createTokenizePaymentMethodBody(instrument: PaymentMethodData, payorId: String? = nil) -> String? {
        if let hostToken = hostToken {
            let ptData = TokenizationPayTheoryData(payorId: payorId)
            let body = TokenizePaymentMethodData(hostToken: hostToken,
                                                 sessionKey: sessionKey ?? "",
                                                 timing: Date().millisecondsSince1970,
                                                 payorInfo: payor,
                                                 payTheoryData: ptData,
                                                 metadata: metadata,
                                                 paymentMethodData: instrument)
            let bodyString = convertToJSONString(body)
            return encryptBody(string: bodyString, action: tokenizeMessage)
        } else {
            return nil
        }
    }
    
    /// Creates an encrypted body for an Apple Pay payment.
    /// - Parameter applePayData: The Apple Pay payment data structure
    /// - Returns: An encrypted JSON string representing the Apple Pay payment data, or nil if the host token is not set
    func createApplePayBody(applePayData: ApplePayPaymentData) -> String? {
        if let hostToken = hostToken {
            let bodyString = convertToJSONString(applePayData)
            return encryptBody(string: bodyString, action: applePayTransaction)
        } else {
            return nil
        }
    }
    
    /// Resets the transaction state.
    ///
    /// This method clears all transaction-related data, preparing the instance for a new transaction.
    func resetTransaction() {
        DispatchQueue.main.async {
            self.hostToken = nil
        }
        sessionKey = ""
        ptInstrument = nil
        amount = 0
    }
}
