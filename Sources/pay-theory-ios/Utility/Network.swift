//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//

import Network
import Foundation

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Monitor")
    
    var isActive = false
    var isExpensive = false
    var isConstrained = false
    var connectionType = NWInterface.InterfaceType.other
    
    init() {
        monitor.pathUpdateHandler = { path in
            self.isActive = path.status == .satisfied
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained

            let connectionTypes: [NWInterface.InterfaceType] = [.cellular, .wifi, .wiredEthernet]
            self.connectionType = connectionTypes.first(where: path.usesInterfaceType) ?? .other

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }

        monitor.start(queue: queue)
    }
}

import Foundation

enum NetworkError: Error {
    case transportError(Error)
    case serverError(statusCode: Int)
    case noData
    case decodingError
    case noConnection
}

func makeRequest(request: URLRequest) async throws -> [String: AnyObject] {
    let config = URLSessionConfiguration.default
    config.allowsExpensiveNetworkAccess = false
    config.allowsConstrainedNetworkAccess = false
    config.waitsForConnectivity = false
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.timeoutIntervalForRequest = 30  // 30 second timeout for the actual connection

    let session = URLSession(configuration: config)
    
    do {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noConnection
        }
                
        // Check for specific status codes that indicate no connectivity
        if httpResponse.statusCode == -1009 || // No internet connection
           httpResponse.statusCode == -1004 || // Could not connect to server
           httpResponse.statusCode == -1005 {  // Network connection lost
            throw NetworkError.noConnection
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject] {
            return json
        } else {
            throw NetworkError.decodingError
        }
    } catch let error as URLError {
        // Handle URLError cases that indicate connectivity issues
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            throw NetworkError.noConnection
        default:
            throw NetworkError.transportError(error)
        }
    } catch {
        throw error
    }
}

func getToken(apiKey: String, environment: String, stage: String, sessionKey: String) async throws -> [String: AnyObject] {
    guard let url = URL(string: "https://\(environment).\(stage).com/pt-token-service/") else {
        throw ConnectionError.hostTokenCallFailed
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    request.setValue(sessionKey, forHTTPHeaderField: "X-Session-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let result = try await makeRequest(request: request)
        return result
    } catch {
        throw ConnectionError.hostTokenCallFailed
    }
}

