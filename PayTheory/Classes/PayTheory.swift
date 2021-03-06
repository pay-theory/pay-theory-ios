//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//
import SwiftUI
import Foundation
import Combine

import DeviceCheck
import CryptoKit

public func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}
public enum Environment {
    case DEMO, PROD

    var value: String {
        switch self {
        case .DEMO:
            return "demo"
        case .PROD:
            return "prod"
    }
    }
}

public class PayTheory: ObservableObject, WebSocketProtocol {
    func receiveMessage(message: String) {
        print("handle receiveMessage")
        print(message)
        onMessage(response: message)
    }
    
    func handleConnect() {
        print("handle connected")
        var message: [String: Any] = ["action": HOST_TOKEN]
        let hostToken: [String: Any] = [
            "ptToken": ptToken!,
            "origin": "native",
            "attestation":attestationString!,
            "timing": Date().millisecondsSince1970
        ]
        message["encoded"] = stringify(jsonDictionary: hostToken).data(using: .utf8)!.base64EncodedString()
        session!.sendMessage(messageBody: stringify(jsonDictionary: message), requiresResponse: session!.REQUIRE_RESPONSE)
    }
    
    func handleError(error: Error) {
        print("handle error")
        print(error)
    }
    
    func handleDisconnect() {
        print("handle disconnected")
    }
    
    let service = DCAppAttestService.shared
    var apiKey: String
    var environment: String
    var stage: String
    var fee_mode: FEE_MODE
    var tags: [String: Any]
    var buttonClicked = false
    @ObservedObject var transaction = Transaction()
    @Published public var buttonDisabled = true
    private var buttonDisabledCancellable: AnyCancellable!
    
    private var encodedChallenge: String = ""
    private var isConnected = false
    private var passedBuyer: Buyer?
    private var ptToken: String?
    private var session: WebSocketSession?
    private var attestationString: String?{
        didSet {
            let provider = WebSocketProvider()
            session = WebSocketSession()
            session!.prepare(_provider: provider, _handler: self)
            session!.open(ptToken:ptToken!, environment: environment, stage: stage)
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        }
           
    }
    
    func onMessage(response: String) {
        if let dictionary = convertStringToDictionary(text: response) {

            if let hostToken = dictionary["hostToken"] {
                DispatchQueue.main.async {
                    self.transaction.hostToken = hostToken as? String ?? ""
                }
                transaction.sessionKey = dictionary["sessionKey"] as? String ?? ""
                let key = dictionary["publicKey"] as? String ?? ""
                self.transaction.publicKey = convertStringToByte(string: key)

            } else if let instrument = dictionary["pt-instrument"] {
                transaction.ptInstrument = instrument as? String ?? ""
                session?.sendMessage(messageBody: transaction.createIdempotencyBody()!, requiresResponse: session!.REQUIRE_RESPONSE)

            } else if let _ = dictionary["payment-token"] {
                transaction.paymentToken = dictionary
                if transaction.feeMode == .SURCHARGE {
                session?.sendMessage(messageBody: transaction.createTransferBody()!, requiresResponse: session!.REQUIRE_RESPONSE)
                } else {
                    transaction.completionHandler?(.success(transaction.createTokenizationResponse()!))
                }

            } else if let state = dictionary["state"] {
                transaction.transferToken = dictionary
                print(dictionary)
                if state as? String ?? "" == "FAILURE" {
                    transaction.completionHandler?(.failure(transaction.createFailureResponse()))
                    resetTransaction()
                } else {
                    if transaction.feeMode == .SURCHARGE {
                        transaction.completionHandler?(.success(transaction.createCompletionResponse()!))
                        transaction.resetTransaction()
                        
                    } else {
                        transaction.completionHandler?(.success(transaction.createCompletionResponse()!))
                        transaction.resetTransaction()
                    }
                }

            } else if let error = dictionary["error"] {
                print(error)
                transaction.completionHandler?(.failure(FailureResponse(type: error as? String ?? "")))
                resetTransaction()
            }
        } else {
            print("Could not convert the response to a Dictionary")
        }
    }


    @objc func appMovedToBackground() {
        session!.close()
    }
    
    @objc func appCameToForeground() {
        getToken(apiKey: apiKey, environment: environment, stage: stage, completion: ptTokenClosure)
    }
    
    func ptTokenClosure(response: Result<[String: AnyObject], Error>) {
        switch response {
            case .success(let token):
                ptToken = token["pt-token"] as? String ?? ""
                if let challenge = token["challengeOptions"]?["challenge"] as? String {
                service.generateKey { (keyIdentifier, error) in
                    guard error == nil else {
                        debugPrint(error ?? "")
                        return
                    }
                    let encodedChallengeData = challenge.data(using: .utf8)!
                    self.encodedChallenge = encodedChallengeData.base64EncodedString()
                    let hash = Data(SHA256.hash(data: encodedChallengeData))
                    self.service.attestKey(keyIdentifier!, clientDataHash: hash) { attestation, error in
                        guard error == nil else {
                            debugPrint(error!)
                            return
                        }
                        self.attestationString = attestation!.base64EncodedString()
                    }
                }
                }
            case .failure(_):
                print("failed to fetch pt-token")
        }
    }
    

    
    public init(apiKey: String,
                tags: [String: Any] = [:],
                fee_mode: FEE_MODE = .SURCHARGE) {
        
        self.apiKey = apiKey
        let apiParts = apiKey.split{$0 == "-"}.map { String($0) }
        
        if apiParts.count != 3 {
            fatalError("API Key should be formatted '{partner}-{paytheorystage}-{number}'")
        }

        self.environment = apiParts[0]
        self.stage = apiParts[1]
        self.fee_mode = fee_mode
        self.tags = tags
        self.envAch = BankAccount()
        self.envCard = PaymentCard()
        self.envBuyer = Buyer()
        self.transaction.feeMode = fee_mode
        self.transaction.apiKey = apiKey
        self.transaction.tags = tags
        buttonDisabledCancellable = buttonDisabledPublisher.sink { buttonDisabled in
            self.buttonDisabled = buttonDisabled
        }
        
        
        getToken(apiKey: apiKey, environment: self.environment, stage: self.stage, completion: ptTokenClosure)
    }
    
    @available(*, deprecated, message: "environment in init is deprecated")
    public convenience init(apiKey: String,
                tags: [String: Any] = [:],
                environment: Environment,
                fee_mode: FEE_MODE = .SURCHARGE) {
        self.init(apiKey: apiKey,tags: tags,fee_mode: fee_mode)
    }
    
    @available(*, deprecated, message: "dev in init is deprecated")
    public convenience init(apiKey: String,
                tags: [String: Any] = [:],
                fee_mode: FEE_MODE = .SURCHARGE,
                dev:String) {
        self.init(apiKey: apiKey,tags: tags,fee_mode: fee_mode)
    }
    
    let envCard: PaymentCard
    let envBuyer: Buyer
    let envAch: BankAccount
    
    var buttonDisabledPublisher: AnyPublisher<Bool,Never> {
        return Publishers.CombineLatest3(envCard.$isValid, envAch.$isValid, transaction.$hostToken)
            .map { validCard, validAch, hostToken in
                return !((validCard || validAch) && hostToken != nil)
            }
            .eraseToAnyPublisher()
    }

    
    func tokenize(card: PaymentCard? = nil,
                  bank: BankAccount? = nil,
                  amount: Int,
                  buyerOptions: Buyer,
                  completion: @escaping (Result<[String: Any], FailureResponse>) -> Void ) {
        if buttonClicked == false {
            self.transaction.completionHandler = completion
            self.transaction.amount = amount
            self.transaction.buyerOptions = buyerOptions
            buttonClicked = true
            if let creditCard = card {
                let body = transaction.createInstrumentBody(instrument: paymentCardToDictionary(card: creditCard)) ?? ""
                session?.sendMessage(messageBody: body, requiresResponse: session!.REQUIRE_RESPONSE)
            } else if let bankAccount = bank {
                let body = transaction.createInstrumentBody(instrument: bankAccountToDictionary(account: bankAccount)) ?? ""
                session?.sendMessage(messageBody: body, requiresResponse: session!.REQUIRE_RESPONSE)
            }
        }
    }
    
    // Calculated value that can allow someone to check if there is an active token
    var isTokenized: Bool {
        if transaction.paymentToken != nil {
            return true
        } else {
            return false
        }
    }
    
    //Used to reset when a transaction fails or an error is returned. Also used by cancel function.
    func resetTransaction() {
        buttonClicked = false
        transaction.resetTransaction()
        getToken(apiKey: apiKey, environment: environment, stage: stage, completion: ptTokenClosure)
    }
    
    //Public function that will void the authorization and relase any funds that may be held.
    public func cancel() {
       resetTransaction()
    }
    
    //Public function that will complete the authorization and send a
    //Completion Response with all the transaction details to the completion handler provided

    public func capture(completion: @escaping (Result<[String: Any], FailureResponse>) -> Void) {
        
        if isTokenized && fee_mode == .SERVICE_FEE {
            transaction.completionHandler = completion
            session?.sendMessage(messageBody: transaction.createTransferBody()!, requiresResponse: session!.REQUIRE_RESPONSE)
        } else {
            let error = FailureResponse(type: "There is no payment authorization to capture")
            print("The capture function should only be used with the .SERVICE_FEE fee mode")
            completion(.failure(error))
        }
    }
}

/// Button that allows a payment to be tokenized once it has the necessary data
/// (Card Number, Expiration Date, and CVV)
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///  - Parameters:
///   - amount: Payment amount that should be charged to the card in cents.
///   - text: String that will be the label for the button.
///   - completion: Function that will handle the result of the
///   tokenization response once it has been returned from the server.
public struct PTButton: View {
    @EnvironmentObject var card: PaymentCard
    @EnvironmentObject var envBuyer: Buyer
    @EnvironmentObject var payTheory: PayTheory
    @EnvironmentObject var bank: BankAccount
    @EnvironmentObject var transaction: Transaction
    @State var disabled = true
    
    var completion: (Result<[String: Any], FailureResponse>) -> Void
    var amount: Int
    var text: String
    var buyer: Buyer?
    var onClick: () -> Void
    
    /// Button that allows a payment to be tokenized once it has the necessary data
    /// (Card Number, Expiration Date, and CVV)
    /// 
    /// - Parameters:
    ///   - amount: Payment amount that should be charged to the card in cents.
    ///   - text: String that will be the label for the button.
    ///   - completion: Function that will handle the result of the
    ///   tokenization response once it has been returned from the server.
    public init(amount: Int,
                text: String = "Confirm",
                buyerOptions: Buyer? = nil,
                onClick: @escaping () -> Void = {return},
                completion: @escaping (Result<[String: Any], FailureResponse>) -> Void) {
        
        self.completion = completion
        self.amount = amount
        self.text = text
        self.onClick = onClick
        self.buyer = buyerOptions
    }
    
    public var body: some View {
        Button {
                onClick()
                if let identity = buyer {
                    if card.isValid {
                            payTheory.tokenize(card: card,
                                               amount: amount,
                                               buyerOptions: identity,
                                               completion: completion)
                    } else if bank.isValid {
                            payTheory.tokenize(bank: bank,
                                               amount: amount,
                                               buyerOptions: identity,
                                               completion: completion)
                    }
                } else {
                    if card.isValid {
                            payTheory.tokenize(card: card,
                                               amount: amount,
                                               buyerOptions: envBuyer,
                                               completion: completion)
                    } else if bank.isValid {
                            payTheory.tokenize(bank: bank,
                                               amount: amount,
                                               buyerOptions: envBuyer,
                                               completion: completion)
                    }
                }
        } label: {
            HStack {
                Spacer()
                Text(text)
                Spacer()
            }
        }
        .disabled(payTheory.buttonDisabled)
    }
}

/// This is used to wrap an ancestor view to allow the TextFields and Buttons to access the data needed.
///
/// - Requires: Needs to have the PayTheory Object that was initialized with the API Key passed as an EnvironmentObject
///
/**
  ````
 let pt = PayTheory(apiKey: 'your-api-key')

 PTForm{
     AncestorView()
 }.EnvironmentObject(pt)
  ````
 */
public struct PTForm<Content>: View where Content: View {

    let content: () -> Content
    @EnvironmentObject var payTheory: PayTheory

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            content()
        }.environmentObject(payTheory.envCard)
        .environmentObject(payTheory.envBuyer)
        .environmentObject(payTheory.envAch)
        .environmentObject(payTheory.transaction)
    }
}
