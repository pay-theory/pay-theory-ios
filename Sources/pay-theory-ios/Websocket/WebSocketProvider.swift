//
//  WebSocketProvider.swift
//  PayTheory
//
//  Created by Aron Price on 4/1/21.
//

import Foundation

/**
 * Responsible for all calls made to websocket server
 */
public class WebSocketProvider: NSObject {
    var webSocket: URLSessionWebSocketTask?
    var handler: WebSocketProtocol?
    private var defaultHandler: WebSocketProtocol?
    private var asyncResponseHandler: ((Result<String, Error>) -> Void)?
    private var connectionCompletion: ((Result<Void, Error>) -> Void)?

    override init() {
        super.init()
    }
    
    func setDefaultHandler(_ handler: WebSocketProtocol) {
        self.defaultHandler = handler
    }
        
    private(set) var status: WebSocketStatus = .notConnected
    
    func startSocket(environment: String,
                     stage: String,
                     ptToken: String,
                     listener: WebSocketListener,
                     socketHandler: WebSocketProtocol) async throws {
        // If we're already connecting or connected, don't try to connect again
        guard status == .notConnected || status == .disconnected else {
            return
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let urlSession = URLSession(configuration: .default, delegate: listener, delegateQueue: OperationQueue())
            let socketUrl = "wss://\(environment).secure.socket.\(stage).com/\(environment)/?pt_token=\(ptToken)"
            handler = socketHandler
            webSocket = urlSession.webSocketTask(with: URL(string: socketUrl)!)
            status = .connecting
            
            connectionCompletion = { [weak self] result in
                guard self != nil else {
                    continuation.resume(throwing: NSError(domain: "WebSocket", code: 0, userInfo: [NSLocalizedDescriptionKey: "WebSocket provider was deallocated"]))
                    return
                }
                
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
                self?.connectionCompletion = nil
            }
            
            self.webSocket!.resume()
            print("Socket connecting...")
        }
    }
    
    func connectionEstablished() {
        status = .connected
        connectionCompletion?(.success(()))
        self.receive()
    }

    func connectionFailed(with error: Error) {
        status = .disconnected
        connectionCompletion?(.failure(error))
    }
    
    func receive() {
            webSocket!.receive { result in
                switch result {
                case .success(let message):
                    self.status = .connected
                    switch message {
                    case .string(let text):
                        if let asyncHandler = self.asyncResponseHandler {
                            asyncHandler(.success(text))
                            self.asyncResponseHandler = nil
                        } else {
                            self.defaultHandler?.receiveMessage(message: text)
                        }
                    default:
                        let error = NSError(domain: "WebSocket", code: 0, userInfo: [NSLocalizedDescriptionKey: "Received unknown response type"])
                        if let asyncHandler = self.asyncResponseHandler {
                            asyncHandler(.failure(error))
                            self.asyncResponseHandler = nil
                        } else {
                            self.defaultHandler?.handleError(error: error)
                        }
                    }
                case .failure(let error):
                    self.status = .disconnected
                    if let asyncHandler = self.asyncResponseHandler {
                        asyncHandler(.failure(error))
                        self.asyncResponseHandler = nil
                    } else {
                        self.defaultHandler?.handleError(error: error)
                    }
                }
                if self.status == .connected {
                    self.receive()
                }
            }
        }

        func sendMessageAndWaitForResponse(message: URLSessionWebSocketTask.Message) async throws -> String {
            return try await withCheckedThrowingContinuation { continuation in
                sendMessage(message: message, handler: defaultHandler!)

                self.asyncResponseHandler = { result in
                    switch result {
                    case .success(let text):
                        continuation.resume(returning: text)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    
    func sendMessage(message: URLSessionWebSocketTask.Message, handler: WebSocketProtocol) {
        if self.asyncResponseHandler != nil {
            print("Cannot send message while waiting for response")
            return
        }
        webSocket?.send(message, completionHandler: { (error) in
            if error != nil {
                self.handler!.handleError(error: error!)
                self.stopSocket()
            }
        })
    }
    
    func stopSocket() {
        status = .disconnected
        webSocket?.cancel(with: .normalClosure, reason: webSocket?.closeReason)
    }
}
    
enum WebSocketStatus {
    case notConnected
    case connecting
    case connected
    case disconnected
}
