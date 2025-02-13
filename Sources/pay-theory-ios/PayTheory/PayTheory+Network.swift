//
//  PayTheory+Helpers.swift
//  PayTheory
//
//  Created by Austin Zani on 8/7/24.
//
// Extension of the Pay Theory class that contains functions
// used for initializes and maintaing the websocket as well as making any HTTP calls

import Foundation
import CryptoKit
import DeviceCheck

enum ConnectionError: Error {
    case attestationFailed
    case hostTokenCallFailed
    case socketConnectionFailed
    case tokenFetchFailed
}

let keyKey = "pt_attestation_key"

extension PayTheory {
    func handleActiveState() {
        // Only attempt reconnection if we were previously connected and went to background
        if session.status == .disconnected {
            Task {
                do {
                    _ = try await ensureConnected()
                } catch {
                    var connectionError: ConnectionError = .socketConnectionFailed
                    if let error = error as? ConnectionError {
                        connectionError = error
                    }
                    _ = handleConnectionError(connectionError, sendToErrorHandler: true)
                }
            }
        }
    }
    
    // Closes the socket as the app goes behind the
    func handleBackgroundState() {
        if session.status == .connected {
            session.close()
        }
    }
    

    
    private func getOrCreateAttestationKey() async throws -> String {
        let defaults = UserDefaults.standard
        
        // Check if the attestation key is passed into the initalizer
        if let attestationKey = self.attestationKey {
            return attestationKey
        }
        
        // Check if we have a saved key
        if let savedKey = defaults.string(forKey: keyKey) {
            return savedKey
        }
        
        // If no saved key, generate a new one
        let newKey = try await service.generateKey()
        
        // Save the new key
        defaults.set(newKey, forKey: keyKey)
        
        return newKey
    }
    
    private func wipeSavedKey() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: keyKey)
    }
    
    func fetchToken() async throws {
        do {
            let tokenData = try await getToken(apiKey: apiKey,
                                             environment: environment,
                                             stage: stage,
                                             sessionKey: sessionId)
            ptToken = tokenData["pt-token"] as? String ?? ""
            if devMode {
                // Skip attestation if it is in devMode for testing in the simulator
                self.attestationString = ""
            } else if attestationString == nil {
                // Go through the attestation process to set the attestation string
                if let challenge = tokenData["challengeOptions"]?["challenge"] as? String {
                    do {
                        let key = try await getOrCreateAttestationKey()
                        let encodedChallengeData = challenge.data(using: .utf8)!
                        let hash = Data(SHA256.hash(data: encodedChallengeData))
                        let attestation = try await service.attestKey(key, clientDataHash: hash)
                        self.attestationString = attestation.base64EncodedString()
                    } catch {
                        if let dcError = error as? DCError {
                            switch dcError.code {
                            case .invalidKey:
                                // Issue with key generation
                                // Wipe the key from memory so that it generates a new one next time
                                wipeSavedKey()
                                throw ConnectionError.attestationFailed
                            default:
                                throw ConnectionError.attestationFailed
                            }
                        }
                        if session.status == .connected {
                            session.close()
                        }
                        throw ConnectionError.attestationFailed
                    }
                } else {
                    if session.status == .connected {
                        session.close()
                    }
                    throw ConnectionError.tokenFetchFailed
                }
            }
        } catch {
            throw ConnectionError.tokenFetchFailed
        }
    }
    
    func connectSocket() async throws  {
        // Prevent multiple simultaneous connection attempts
        guard !isConnecting else {
            // Wait for existing connection attempt to complete
            while isConnecting {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            // If connected after waiting, return
            if session.status == .connected {
                return
            }
            // If still not connected, continue with new connection attempt
            return try await connectSocket()
        }
        
        isConnecting = true
        defer { isConnecting = false }
        
        // Fetch the PT Token to pass into socket connection
        do {
            try await fetchToken()
        } catch ConnectionError.attestationFailed {
            throw ConnectionError.attestationFailed
        } catch {
            throw ConnectionError.tokenFetchFailed
        }
        // Open the websocket
        do {
            try await session.open(ptToken: ptToken!, environment: environment, stage: stage)
        } catch {
            throw ConnectionError.socketConnectionFailed
        }
        
        //Send the host token message
        do {
            try await sendHostTokenMessage()
        } catch {
            throw error
        }
    }
    
    func handleConnectionError(_ error: Error, sendToErrorHandler: Bool = true) -> PTError {
        let parsedError: PTError
        switch error {
        case ConnectionError.attestationFailed:
            parsedError = PTError(code: .attestationFailed, error: "Failed app attestation")
        case ConnectionError.socketConnectionFailed:
            parsedError = PTError(code: .socketError, error: "Socket failed to connect")
        case ConnectionError.hostTokenCallFailed:
            parsedError = PTError(code: .tokenFailed, error: "Host token message failed")
        case ConnectionError.tokenFetchFailed:
            parsedError = PTError(code: .tokenFailed, error: "There was an error fetching the token")
        default:
            parsedError = PTError(code: .socketError, error: "An unknown error occurred")
        }
        if sendToErrorHandler {
            self.errorHandler(parsedError)
        }
        return parsedError
    }
    
    /// Checks to see if the socket is connected
    /// Returns true if socket was already connected or false if it had to reconnect
    func ensureConnected() async throws -> Bool {
        // Check if the socket is already connected
        if session.status == .connected {
            // Verify host token is still valid
            if hostTokenStillValid() {
                return true
            }
            // If host token expired, close connection to force reconnect
            session.close()
        }
        
        // If not connected, try to reconnect
        do {
            try await connectSocket()
            return false
        } catch {
            throw error
        }
    }
}
