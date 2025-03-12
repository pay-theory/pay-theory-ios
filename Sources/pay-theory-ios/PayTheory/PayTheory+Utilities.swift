//
//  PayTheory+Helpers.swift
//  PayTheory
//
//  Created by Austin Zani on 8/7/24.
//
// Extension of the Pay Theory class that contains helper functions and utilities for the PayTheory class

import Foundation

extension PayTheory {
    
    // Used to reset when a transaction fails or an error is returned. Also used by cancel function.
    func resetTransaction() {
        isInitialized = false
        transaction.resetTransaction()
        Task {
            do {
                let connected = try await ensureConnected()
                if connected == true {
                    try await fetchToken()
                    try await sendHostTokenMessage()
                }
            } catch {
                self.errorHandler(PTError(code: .tokenFailed, error: "Fetching the token failed"))
            }
        }
    }
    
    func calcFeesWithAmount () {
        if let _ = amount {
            // Send calc fee for Bank Fee
            sendCalcFeeMessage()
            if let cardBin = cardBin {
                sendCalcFeeMessage(cardBin: cardBin)
            }
        }
    }
    
    /// Function that checks the new card number and updates the cardBin if it has changed
    ///
    /// If it is greater than 6 and is different than what is set in the cardBin then we should set the value to the new value
    ///
    /// If the new value is less than 6 characters then we should set the cardBin to nil
    func cardNumberChanged(_ newNumber: String) {
        // Strip non-numerical characters
        let numericString = newNumber.filter { $0.isNumber }
        
        // Ensure it's 6 characters or longer and compare to cardBin. Set if needed.
        if numericString.count >= 6 {
            let firstSixDigits = String(numericString.prefix(6))
            if firstSixDigits != cardBin {
                cardBin = firstSixDigits
            }
        } else {
            if cardBin != nil {
                cardBin = nil
            }
        }
    }
    
    func canCallAction() -> PTError? {
        if isComplete == true {
            return PTError(code: .actionComplete, error: "Pay Theory class has already succesfully tokenized or made a transaction.")
        } else if isInitialized == true {
            return PTError(code: .inProgress, error: "Transact or Tokenize function is already in progress.")
        }
        return nil
    }
        
    // Checks to see that it has been 14 minutes since we fetched the host token so that it can be used
    func hostTokenStillValid() -> Bool {
        let currentTime = Date()
        if let hostTokenTimestamp = self.hostTokenTimestamp {
            let timeInterval = currentTime.timeIntervalSince(hostTokenTimestamp)
            let minutesPassed = timeInterval / 60
            return minutesPassed <= Double(14)
        }
        return false
    }
    
    // Some internal setters for values that need to be set on the main thread
    func setReady(_ newValue: Bool) {
        DispatchQueue.main.async {
            self.isReady = newValue
        }
    }
    
    func setComplete(_ newValue: Bool) {
        DispatchQueue.main.async {
            self.isComplete = newValue
        }
    }
}
