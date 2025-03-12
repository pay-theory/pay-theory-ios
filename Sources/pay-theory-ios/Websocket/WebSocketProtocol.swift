//
//  WebSocketProtocol.swift
//  PayTheory
//
//  Created by Aron Price on 4/1/21.
//

import Foundation
/**
 * Protocol for reacting to websocket events
 */
protocol WebSocketProtocol {

    /**
     process incoming messages
     */
    func receiveMessage(message:String)
    
    /**
     react to an error
     */
    func handleError(error:Error)
    
    /**
     reconnect if transaction not initiated
     report failure if transaction already began
     */
    func handleDisconnect()

}
