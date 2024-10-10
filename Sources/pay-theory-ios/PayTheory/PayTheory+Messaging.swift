//
//  PayTheory+Helpers.swift
//  PayTheory
//
//  Created by Austin Zani on 8/7/24.
//
// Extension of the Pay Theory class that contains functions used for messaging the websocket and also handling messages from the socket

import Foundation
import CryptoKit

extension PayTheory {
    
    private func parseResponse(response: String) -> Result<(type: String, body: [String: Any]), PTError> {
        // Attempt to convert the response string to a dictionary
        guard let dictionary = convertStringToDictionary(text: response) else {
            // If conversion fails, handle it as an error and exit
            return .failure(handleErrors(["Could not convert the response to a Dictionary"]))
        }

        // Extract the message type, defaulting to an empty string if not present
        let type = dictionary["type"] as? String ?? ""
        
        // Check if the response contains any errors
        if let errors = dictionary["error"] as? [Any] {
            // If errors are present, handle them and exit
            return .failure(handleErrors(errors))
        }

        // Attempt to extract the body from the response
        guard let body = dictionary["body"] else {
            // If body is missing, handle it as an error and exit
            return .failure(handleErrors(["Missing body in response"]))
        }
        
        // Check if body is a String or [String: Any]
        var parsedBody: [String: Any]
        if var stringBody = body as? String {
            // If the message type requires decryption, decrypt the body
            if ENCRYPTED_MESSAGES.contains(type) {
                let publicKey = dictionary["public_key"] as? String ?? ""
                stringBody = transaction.decryptBody(body: stringBody, publicKey: publicKey)
                // Attempt to parse the body string into a dictionary
                guard let parsed = convertStringToDictionary(text: stringBody) else {
                    // If parsing fails, handle it as an error and exit
                    return .failure(handleErrors(["Could not parse body"]))
                }
                parsedBody = parsed
            } else if type == ERROR_TYPE {
                return .failure(handleErrorType(stringBody))
            } else {
                return .failure(handleErrors(["Invalid body type in response"]))
            }
        } else if let dictBody = body as? [String: Any] {
            parsedBody = dictBody
        } else {
            // If body is neither String nor [String: Any], handle as error and exit
            return .failure(handleErrors(["Invalid body type in response"]))
        }
        
        return .success((type, parsedBody))
    }
    
    func onMessage(response: String) {
        let response = parseResponse(response: response)
        if case .failure(let error) = response {
            self.errorHandler(error)
        } else if case .success(let (type, parsedBody)) = response {
            // Process the message based on its type
            handleMessageType(type, parsedBody)

            // Perform any necessary cleanup or final processing
            finishProcessing()
        }
    }

    private func handleErrors(_ errors: [Any]) -> PTError {
        let errorMessage = errors.compactMap { $0 as? String }.joined()
        let error = errorMessage.isEmpty ? "An unknown socket error occurred" : errorMessage
        let ptError = PTError(code: .socketError, error: error)
        if transaction.hostToken != nil {
            resetTransaction()
        }
        return ptError
    }

    private func handleErrorType(_ body: String) -> PTError {
        if transaction.hostToken != nil {
            resetTransaction()
        }
        return PTError(code: .socketError, error: body)
    }

    private func handleMessageType(_ type: String, _ parsedBody: [String: Any]) {
        switch type {
        case CALCULATE_FEE_TYPE:
            handleCalcFeeResponse(parsedBody)
        default:
            debugPrint("Type not recognized. \(type)")
        }
    }

    private func finishProcessing() {
        if isAwaitingResponse {
            isAwaitingResponse = false
        }
    }
    
    // Used to parse transaction repsponses to be used in the transact function logic
    func parseTransactResponse(_ response: String) -> TransactResponse {
        let response = parseResponse(response: response)
        if case .failure(let error) = response {
            return .Error(error)
        } else if case .success(let (type, parsedBody)) = response {
            switch type {
            case TRANSFER_COMPLETE_TYPE:
                if parsedBody["state"] as? String ?? "" == "FAILURE" {
                    resetTransaction()
                    return .Failure(FailedTransaction(response: parsedBody))
                } else {
                    setComplete(true)
                    return .Success(SuccessfulTransaction(response: parsedBody))
                }
            case BARCODE_COMPLETE_TYPE:
                setComplete(true)
                return .Barcode(CashBarcode(response: parsedBody))
            default:
                return .Error(PTError(code: .socketError, error: "Unknown response type: \(type)"))
            }
        }
        resetTransaction()
        return .Error(PTError(code: .socketError, error: "Unknown response type."))
    }
    
    // Used to parse the tokenization responses to be used in the tokenizePaymentMethod function logic
    func parseTokenizeResponse(_ response: String) -> TokenizePaymentMethodResponse {
        let response = parseResponse(response: response)
        if case .failure(let error) = response {
            return .Error(error)
        } else if case .success(let (type, parsedBody)) = response {
            switch type {
            case TOKENIZE_COMPLETE_TYPE:
                setComplete(true)
                return .Success(TokenizedPaymentMethod(response: parsedBody))
            default:
                return .Error(PTError(code: .socketError, error: "Unknown response type: \(type)"))
            }
        }
        resetTransaction()
        return .Error(PTError(code: .socketError, error: "Unknown response type."))
    }
    
    // Create the body needed for fetching a Host Token and send it to the websocket
    func sendHostTokenMessage(calc_fees: Bool = true) async throws {
        do {
            var message: [String: Any] = ["action": HOST_TOKEN]
            let hostToken: [String: Any] = [
                "ptToken": ptToken ?? "",
                "origin": "apple",
                "attestation": attestationString ?? "",
                "timing": Date().millisecondsSince1970,
                "appleEnvironment": appleEnvironment
            ]

            guard let encodedData = stringify(jsonDictionary: hostToken).data(using: .utf8) else {
                throw ConnectionError.hostTokenCallFailed
            }
            message["encoded"] = encodedData.base64EncodedString()
            
            let response = try await session.sendMessageAndWaitForResponse(messageBody: stringify(jsonDictionary: message))
            
            // Parse response
            guard let dictionary = convertStringToDictionary(text: response) else {
                throw ConnectionError.hostTokenCallFailed
            }
            
            guard let type = dictionary["type"] as? String, type == HOST_TOKEN_TYPE else {
                throw ConnectionError.hostTokenCallFailed
            }
            
            // Set the values from the response on the class variables they associate with
            let body = dictionary["body"] as? [String: AnyObject] ?? [:]
            DispatchQueue.main.async {
                self.transaction.hostToken = body["hostToken"] as? String ?? ""
            }
            transaction.sessionKey = body["sessionKey"] as? String ?? ""
            let key = body["publicKey"] as? String ?? ""
            self.transaction.publicKey = convertStringToByte(string: key)
            
            // Set isReady to true, set the timestamp for the host token, and calc fees if needed
            setReady(true)
            self.hostTokenTimestamp = Date()
            if calc_fees && (amount != nil) {
                calcFeesWithAmount()
            }
        } catch {
            throw ConnectionError.hostTokenCallFailed
        }
    }

    // Create the body for calculating the fee and messaging the websocket to calc the fee.
    func sendCalcFeeMessage(card_bin: String? = nil) {
        Task {
            do {
                let _ = try await ensureConnected()
            } catch {
                let _ = handleConnectionError(error)
            }
        }
        print("Calculating Fees \(card_bin ?? "ACH")")
        if let calcAmount = amount {
            var message: [String: Any] = ["action": CALCULATE_FEE]
            if let bin = card_bin {
                // Build calc fee message if we are calculating for a card
                let calcFeeBody: [String: Any] = [
                    "amount": calcAmount,
                    "is_ach": false,
                    "bank_id": bin,
                    "timing": Date().millisecondsSince1970
                ]
                message["encoded"] = stringify(jsonDictionary: calcFeeBody).data(using: .utf8)!.base64EncodedString()
            } else {
                // Build a calc fee message if we are calculating for a bank account
                let calcFeeBody: [String: Any] = [
                    "amount": calcAmount,
                    "is_ach": true,
                    "bank_id": NSNull(),
                    "timing": Date().millisecondsSince1970
                ]
                message["encoded"] = stringify(jsonDictionary: calcFeeBody).data(using: .utf8)!.base64EncodedString()
            }
            do {
                try session.sendMessage(messageBody: stringify(jsonDictionary: message))
            } catch {
                errorHandler(PTError(code: .socketError, error: "There was an error sending the socket message"))
            }
        }
    }
    
    func handleCalcFeeResponse(_ response: [String: Any]) {
        if let fee = response["fee"] as? Int {
            if let bank_id = response["bank_id"] as? String {
                // Only set the cardServiceFee if it is for the correct current cardBin.
                // This needs to be here in case someone changes the card number quickly before the response comes through
                if bank_id == cardBin {
                    DispatchQueue.main.async {
                        self.cardServiceFee = fee
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.bankServiceFee = fee
                }
            }
        } else {
            self.errorHandler(PTError(code: .socketError, error: "There was an error calculating the fees"))
        }
    }
}
