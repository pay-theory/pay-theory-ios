//
//  WebsocketSession.swift
//  PayTheory
//
//  Created by Aron Price on 4/1/21.
//

import Foundation
/**
 * Responsible for managing websocket session
 * including closing and restarting as appropriate
 */
public class WebSocketSession: NSObject {
    private var isClosed: Bool?
    private var provider: WebSocketProvider?
    private var listener: WebSocketListener?
    public let REQUIRE_RESPONSE = true
    var handler: WebSocketProtocol?
    
    func prepare(_provider: WebSocketProvider, _handler: WebSocketProtocol) {
        self.handler = _handler
        self.provider = _provider
        self.listener = WebSocketListener()
        self.listener?.prepare(_session: self)
    }
    
    func open(ptToken: String, environment: String = "finix") {

        self.provider!.startSocket(environment: environment, ptToken: ptToken, listener: self.listener!, _handler: self.handler!)
        
    }

    func close() {
        self.provider!.stopSocket()
    }

    
    func sendMessage(action: String, messageBody: [String: Any], requiresResponse: Bool = false) {
        var message: [String: Any] = [
            "action": action
        ]
        if action == HOST_TOKEN {
            message["encoded"] = stringify(jsonDictionary: messageBody).data(using: .utf8)!.base64EncodedString()
        }
        self.provider!.sendMessage(message: .string(stringify(jsonDictionary: message)), handler: self.handler!)
        
        if (requiresResponse) {
            self.provider!.receive()
        }
    }
}