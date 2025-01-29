//
//  Responses.swift
//  PayTheory
//
//  Created by Austin Zani on 8/5/24.
//

/// Represents the possible responses from a transaction operation.
public enum TransactResponse {
    /// Represents generation of a successful cash barcode.
    case barcode(CashBarcode)
    /// Represents an error in the transaction process.
    case error(PTError)
    /// Represents a failed transaction.
    case failure(FailedTransaction)
    /// Represents a successful transaction.
    case success(SuccessfulTransaction)
}

/// Represents the possible responses from a tokenize payment method operation.
public enum TokenizePaymentMethodResponse {
    /// Represents a successfully tokenized payment method.
    case success(TokenizedPaymentMethod)
    /// Represents an error in the tokenization process.
    case error(PTError)
}

/// Represents a successful transaction in the PayTheory system.
public struct SuccessfulTransaction {
    /// The unique identifier for the transaction.
    public var transactionId: String
    /// The last four digits of the payment method used.
    public var lastFour: String
    /// The brand of the payment method used.
    public var brand: String
    /// The creation date and time of the transaction.
    public var createdAt: String
    /// The amount of the transaction.
    public var amount: Int
    /// The service fee associated with the transaction.
    public var serviceFee: Int
    /// The current status of the transaction.
    public var status: String
    /// Additional metadata associated with the transaction.
    public var metadata: [String: Any]
    /// The unique identifier for the payor.
    public var payorId: String
    /// The unique identifier for the payment method used.
    public var paymentMethodId: String

    /// Initializes a new instance of `SuccessfulTransaction` from a response dictionary.
    /// - Parameter response: A dictionary containing the transaction details.
    init(response: [String: Any]) {
        self.transactionId = response["receipt_number"] as? String ?? ""
        self.lastFour = response["last_four"] as? String ?? ""
        self.brand = response["brand"] as? String ?? ""
        self.createdAt = response["created_at"] as? String ?? ""
        self.amount = response["amount"] as? Int ?? 0
        self.serviceFee = response["service_fee"] as? Int ?? 0
        self.status = response["state"] as? String ?? ""
        self.metadata = response["metadata"] as? [String: Any] ?? [:]
        self.payorId = response["payor_id"] as? String ?? ""
        self.paymentMethodId = response["payment_method_id"] as? String ?? ""
    }
}

/// Represents a tokenized payment method in the PayTheory system.
public struct TokenizedPaymentMethod {
    /// The unique identifier for the payment method.
    public var paymentMethodId: String
    /// The unique identifier for the payor.
    public var payorId: String
    /// The last four digits of the payment method.
    public var lastFour: String
    /// The brand of the payment method.
    public var brand: String
    /// The expiration date of the payment method.
    public var expiration: String
    /// The type of payment method.
    public var paymentType: String
    /// Additional metadata associated with the payment method.
    public var metadata: [String: Any]

    /// Initializes a new instance of `TokenizedPaymentMethod` from a response dictionary.
    /// - Parameter response: A dictionary containing the tokenized payment method details.
    init(response: [String: Any]) {
        self.paymentMethodId = response["payment_method_id"] as? String ?? ""
        self.payorId = response["payor_id"] as? String ?? ""
        self.lastFour = response["last_four"] as? String ?? ""
        self.brand = response["card_brand"] as? String ?? ""
        self.expiration = response["exp_date"] as? String ?? ""
        self.paymentType = response["payment_type"] as? String ?? ""
        self.metadata = response["metadata"] as? [String: Any] ?? [:]
    }
}

/// Extracts failure details from a response dictionary.
/// - Parameter response: A dictionary containing the response details.
/// - Returns: A tuple containing the error code and error text.
func extractFailureDetails(from response: [String: Any]) -> (errorCode: String, errorText: String) {
    // Navigate through the nested dictionary to extract the values
    if let body = response["body"] as? [String: Any],
       let status = body["status"] as? [String: Any],
       let reason = status["reason"] as? [String: Any] {
        let errorCode = reason["error_code"] as? String ?? ""
        let errorText = reason["error_text"] as? String ?? ""

        return (errorCode, errorText)
    }
    
    // Return empty strings if any of the keys are not found
    return ("", "")
}

/// Represents a failed transaction in the PayTheory system.
public struct FailedTransaction {
    /// The unique identifier for the transaction.
    public var transactionId: String
    /// The last four digits of the payment method used.
    public var lastFour: String
    /// The brand of the payment method used.
    public var brand: String
    /// The current state of the transaction.
    public var status: String
    /// The unique identifier for the payor.
    public var payorId: String
    /// The code associated with the failure.
    public var failureCode: String
    /// The text description of the failure.
    public var failureText: String

    /// Initializes a new instance of `FailedTransaction` from a response dictionary.
    /// - Parameter response: A dictionary containing the failed transaction details.
    init(response: [String: Any]) {
        self.transactionId = response["receipt_number"] as? String ?? ""
        self.lastFour = response["last_four"] as? String ?? ""
        self.brand = response["brand"] as? String ?? ""
        self.status = response["state"] as? String ?? ""
        self.payorId = response["payor_id"] as? String ?? ""
        let failureDetails = extractFailureDetails(from: response)
        self.failureCode = failureDetails.errorCode
        self.failureText = failureDetails.errorText
    }
}

/// Represents a cash barcode for payment in the PayTheory system.
public struct CashBarcode {
    /// The URL of the barcode image.
    public var barcodeUrl: String
    /// The unique identifier for the barcode.
    public var barcodeId: String
    /// The URL for the map of payment locations.
    public var mapUrl = "https://pay.vanilladirect.com/pages/locations"

    /// Initializes a new instance of `CashBarcode` from a response dictionary.
    /// - Parameter response: A dictionary containing the cash barcode details.
    init(response: [String: Any]) {
        self.barcodeUrl = response["barcode_url"] as? String ?? ""
        self.barcodeId = response["barcode_id"] as? String ?? ""
    }
}

/// Represents the possible error codes in the PayTheory system.
public enum PTErrorCode: String {
    case actionComplete
    case actionInProgress
    case applePayError
    case attestationFailed
    case inProgress
    case invalidAPIKey
    case invalidParam
    case noFields
    case notReady
    case notValid
    case socketError
    case tokenFailed
}

/// Represents an error in the PayTheory system.
public struct PTError: Error, Equatable {
    /// The error code.
    public var code: PTErrorCode
    /// The error message.
    public var error: String

    /// Initializes a new instance of `PTError`.
    /// - Parameters:
    ///   - code: The error code.
    ///   - error: The error message.
    public init(code: PTErrorCode, error: String) {
        self.code = code
        self.error = error
    }

    /// Compares two `PTError` instances for equality.
    /// - Parameters:
    ///   - lhs: The left-hand side `PTError` instance.
    ///   - rhs: The right-hand side `PTError` instance.
    /// - Returns: `true` if the instances are equal, `false` otherwise.
    public static func == (lhs: PTError, rhs: PTError) -> Bool {
        if lhs.code == rhs.code &&
            lhs.error == rhs.error {
            return true
        }
        return false
    }
}

/// Represents a service fee model in the PayTheory system.
public struct ServiceFeeModel: Decodable {
    /// The basis points for the fee calculation
    public var basisPoints: Int
    /// The fixed fee amount
    public var fixed: Int
    /// The minimum fee amount
    public var minFee: Int
    
    enum CodingKeys: String, CodingKey {
        case basisPoints = "basis_points"
        case fixed
        case minFee = "min_fee"
    }
}

/// Represents a host token response from the PayTheory system.
public struct HostTokenResponse {
    /// The host token for the transaction
    public var hostToken: String
    /// The merchant unique identifier
    public var merchantUid: String
    /// The public key for encryption
    public var publicKey: String
    /// The session key for the transaction
    public var sessionKey: String
    /// The service fee model for debit transactions
    public var debitServiceFeeModel: ServiceFeeModel
    /// The service fee model for credit transactions
    public var creditServiceFeeModel: ServiceFeeModel
    /// The currency code
    public var currency: String
    /// The country code
    public var country: String
    
    /// Initializes a new instance of `HostTokenResponse` from a response dictionary.
    /// - Parameter response: A dictionary containing the host token response details.
    init(response: [String: Any]) {
        self.hostToken = response["hostToken"] as? String ?? ""
        self.merchantUid = response["merchantUid"] as? String ?? ""
        self.publicKey = response["publicKey"] as? String ?? ""
        self.sessionKey = response["sessionKey"] as? String ?? ""
        
        if let debitModel = response["debit_service_fee_model"] as? [String: Any] {
            self.debitServiceFeeModel = ServiceFeeModel(
                basisPoints: debitModel["basis_points"] as? Int ?? 0,
                fixed: debitModel["fixed"] as? Int ?? 0,
                minFee: debitModel["min_fee"] as? Int ?? 0
            )
        } else {
            self.debitServiceFeeModel = ServiceFeeModel(basisPoints: 0, fixed: 0, minFee: 0)
        }
        
        if let creditModel = response["credit_service_fee_model"] as? [String: Any] {
            self.creditServiceFeeModel = ServiceFeeModel(
                basisPoints: creditModel["basis_points"] as? Int ?? 0,
                fixed: creditModel["fixed"] as? Int ?? 0,
                minFee: creditModel["min_fee"] as? Int ?? 0
            )
        } else {
            self.creditServiceFeeModel = ServiceFeeModel(basisPoints: 0, fixed: 0, minFee: 0)
        }
        
        self.currency = response["currency"] as? String ?? ""
        self.country = response["country"] as? String ?? ""
    }
}

