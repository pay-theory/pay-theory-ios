//
//  WebsocketSession.swift
//  PayTheory
//
//  Created by Aron Price on 4/1/21.
//

import Foundation

/// A class responsible for managing WebSocket sessions in the PayTheory system.
///
/// `WebSocketSession` handles the lifecycle of a WebSocket connection, including
/// initialization, opening and closing connections, and sending messages.
public class WebSocketSession: NSObject {
    /// The handler for WebSocket events and messages.
    var handler: WebSocketProtocol?
    
    /// The listener for WebSocket events.
    private var listener: WebSocketListener?
    
    /// The provider responsible for the actual WebSocket implementation.
    var provider: WebSocketProvider?
    
    /// The current status of the WebSocket connection.
    var status: WebSocketStatus {
        return provider?.status ?? .notConnected
    }
    
    /// Prepares the WebSocket session with the necessary components.
    ///
    /// - Parameters:
    ///   - _provider: The WebSocket provider to be used for the connection.
    ///   - _handler: The handler for WebSocket events and messages.
    func prepare(_provider: WebSocketProvider, _handler: WebSocketProtocol) {
        self.handler = _handler
        self.listener = WebSocketListener()
        self.provider = _provider
        self.listener?.prepare(_session: self)
        self.provider?.setDefaultHandler(_handler)
    }
    
    /// Opens a WebSocket connection.
    ///
    /// - Parameters:
    ///   - ptToken: The PayTheory token for authentication.
    ///   - environment: The environment to connect to.
    ///   - stage: The stage of the environment.
    ///
    /// - Throws: `ConnectionError.socketConnectionFailed` if the connection fails.
    func open(ptToken: String, environment: String, stage: String) async throws {
        guard let provider = self.provider else {
            throw ConnectionError.socketConnectionFailed
        }
        do {
            try await provider.startSocket(environment: environment,
                                           stage: stage,
                                           ptToken: ptToken,
                                           listener: self.listener!,
                                           socketHandler: self.handler!)
        } catch {
            throw ConnectionError.socketConnectionFailed
        }
    }

    /// Closes the WebSocket connection.
    func close() {
        self.provider!.stopSocket()
    }

    /// Sends a message through the WebSocket connection.
    ///
    /// - Parameter messageBody: The message to be sent.
    ///
    /// - Throws: An error if the WebSocket provider is not initialized.
    func sendMessage(messageBody: String) throws {
        guard let provider = self.provider else {
            throw NSError(domain: "WebSocket", code: 0, userInfo: [NSLocalizedDescriptionKey: "WebSocket provider is not initialized"])
        }
        provider.sendMessage(message: .string(messageBody), handler: self.handler!)
    }
    
    /// Sends a message through the WebSocket connection and waits for a response.
    ///
    /// - Parameter messageBody: The message to be sent.
    ///
    /// - Returns: The response received from the server.
    ///
    /// - Throws: An error if the WebSocket provider is not initialized or if sending fails.
    func sendMessageAndWaitForResponse(messageBody: String) async throws -> String {
        guard let provider = self.provider else {
            throw NSError(domain: "WebSocket", code: 0, userInfo: [NSLocalizedDescriptionKey: "WebSocket provider is not initialized"])
        }
        
        let message = URLSessionWebSocketTask.Message.string(messageBody)
        return try await provider.sendMessageAndWaitForResponse(message: message)
    }
}
