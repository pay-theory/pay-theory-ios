//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//
import SwiftUI
import Foundation

import DeviceCheck
import CryptoKit

import AWSKMS

public func ??<T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}
public enum Environment: Int {
    case DEV = 0
    case DEMO = 1
    case PROD = 2
}

public class PayTheory: ObservableObject {
    
    let service = DCAppAttestService.shared
    
    var apiKey: String
    var environment: Environment
    
    private var tokenResponse: TokenizationResponse?
    private var idempotencyResponse: IdempotencyResponse?
    private var passedBuyer: Buyer?
    
    private var card = PaymentCard()
    
    
    public init(apiKey: String, environment: Environment = .DEMO){
        self.apiKey = apiKey
        self.environment = environment
    }
    
    let envCard = PaymentCard()
    let envBuyer = Buyer()
    let envAch = BankAccount()
    
    //Function that will tokenize  but needs to either be cancelled or captured before the payment goes through. Allows for there to be a confirmation step in the transaction process
    
    func tokenize(card: PaymentCard, amount: Int,  buyerOptions: Buyer, fee_mode: FEE_MODE, tags: [String: Any], completion: @escaping (Result<TokenizationResponse, FailureResponse>) -> Void ) {
        
        //Closure to run once the challenge has been retrieved from the PT Server
        func challengeClosure(response: Result<Challenge, Error>) {
            switch response {
            case .success(let challenge):
                service.generateKey { (keyIdentifier, error) in
                    guard error == nil else {
                        debugPrint(error ?? "")
                        return
                    }
                    let encodedChallenge = challenge.challenge.data(using: .utf8)!
                    let hash = Data(SHA256.hash(data: encodedChallenge))
                    self.service.attestKey(keyIdentifier!, clientDataHash: hash) { attestation, error in
                        guard error == nil else {
                            debugPrint(error ?? "")
                            return
                        }
                        let attest = Attestation(attestation: attestation!.base64EncodedString(), nonce: encodedChallenge.base64EncodedString(), key: keyIdentifier!, currency: "USD", amount: amount, fee_mode: fee_mode)
                        postIdempotency(body: attest, apiKey: self.apiKey, endpoint: self.environment.rawValue, completion: idempotencyClosure)
                    }
                }
            
            case .failure(let error):
                debugPrint(error.localizedDescription)
                completion(.failure(FailureResponse(type: error.localizedDescription)))
            }
        }
        
        //Closure to run once the idempotency has been retrieved from the PT Server
        func idempotencyClosure(response: Result<IdempotencyResponse, Error>) {
            switch response {
            case .success(let response):
                if envCard.isValid {
                    idempotencyResponse = response
                    tokenResponse = TokenizationResponse(receipt_number: response.idempotency, first_six: envCard.first_six, brand: "visa", amount: response.payment.amount, convenience_fee: response.payment.service_fee)
                    completion(.success(tokenResponse!))
                } else if envAch.isValid {
                    idempotencyResponse = response
                    tokenResponse = TokenizationResponse(receipt_number: response.idempotency, first_six: envCard.first_six, brand: "visa", amount: response.payment.amount, convenience_fee: response.payment.service_fee)
                    completion(.success(tokenResponse!))
                }
                
            case .failure(let error):
                debugPrint(error.localizedDescription)
                completion(.failure(FailureResponse(type: error.localizedDescription)))
            }
        }
        
        getChallenge(apiKey: apiKey, endpoint: environment.rawValue, completion: challengeClosure)
    }
    
    // Calculated value that can allow someone to check if there is an active token
    public var isTokenized: Bool {
        if idempotencyResponse != nil {
            return true
        } else {
            return false
        }
    }
    
    
    //Public function that will void the authorization and relase any funds that may be held.

    public func cancel() {
        tokenResponse = nil
        idempotencyResponse = nil
    }
//
//
    //Public function that will complete the authorization and send a Completion Response with all the transaction details to the completion handler provided

    public func capture(completion: @escaping (Result<CompletionResponse, FailureResponse>) -> Void) {

        func captureCompletion(response: Result<[String: AnyObject], Error>) {
            switch response {
                case .success(let responseAuth):
                    let complete = CompletionResponse(receipt_number: idempotencyResponse!.idempotency, last_four: envCard.last_four, brand: "Visa", created_at: responseAuth["created_at"] as! String, amount: responseAuth["amount"] as! Int, convenience_fee: responseAuth["service_fee"] as! Int, state: responseAuth["state"] as! String)
                    completion(.success(complete))
                    tokenResponse = nil
                    idempotencyResponse = nil
                    envCard.clear()
                    envBuyer.clear()

                case .failure(let error):
                    debugPrint("Your capture failed! \(error.localizedDescription)")
                }
        }

        if let idempotency = idempotencyResponse {
            let body: [String: Any] = [
                "response" : idempotency.response,
                "credId" : idempotency.credId,
                "signature" : idempotency.signature,
                "buyer-options" : buyerToDictionary(buyer: envBuyer),
                "payment" : paymentCardToDictionary(card: envCard)
            ]
                postPayment(body: body, apiKey: apiKey, endpoint: self.environment.rawValue, completion: captureCompletion)
        } else {
            let error = FailureResponse(type: "There is no auth to capture")
            completion(.failure(error))
        }
    }
}

//These fields are for capturing the card info required to create a payment card associated with an identity to run a transaction

/// TextField that can be used to capture the Name for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardName: View {
    @EnvironmentObject var card: PaymentCard
    public init() {
    }

    public var body: some View {
        TextField("Name on Card", text: $card.name ?? "")
    }
}

/// TextField that can be used to capture the Card Number for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
///  - Important: This is required to be able to run a transaction.
///
public struct PTCardNumber: View {
    @EnvironmentObject var card: PaymentCard
    public init(){
        
    }
    public var body: some View {
        TextField("Card Number", text: $card.number)
            .keyboardType(.decimalPad)
    }
}

/// TextField that can be used to capture the Expiration Year for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
///  - Important: This is required to be able to run a transaction.
///
public struct PTExpYear: View {
    @EnvironmentObject var card: PaymentCard
    public init(){
        
    }
    public var body: some View {
        TextField("Expiration Year", text: $card.expiration_year)
            .keyboardType(.decimalPad)
    }
}

/// TextField that can be used to capture the Expiration Month for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
///  - Important: This is required to be able to run a transaction.
///
public struct PTExpMonth: View {
    @EnvironmentObject var card: PaymentCard
    public init(){
        
    }
    public var body: some View {
        TextField("Expiration Month", text: $card.expiration_month)
            .keyboardType(.decimalPad)
    }
}

/// TextField that can be used to capture the CVV for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
///  - Important: This is required to be able to run a transaction.
///
public struct PTCvv: View {
    @EnvironmentObject var card: PaymentCard
    public init(){
        
    }
    public var body: some View {
        TextField("CVV", text: $card.security_code)
            .keyboardType(.decimalPad)
    }
}

/// TextField that can be used to capture the Address Line 1 for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardLineOne: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("Address Line 1", text: $card.address.line1 ?? "")
    }
}

/// TextField that can be used to capture the Address Line 2 for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardLineTwo: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("Address Line 2", text: $card.address.line2 ?? "")
    }
}

/// TextField that can be used to capture the City for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardCity: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("City", text: $card.address.city ?? "")
    }
}

/// TextField that can be used to capture the State for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PYCardState: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("State", text: $card.address.region ?? "")
    }
}

/// TextField that can be used to capture the Zip for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardZip: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("Zip", text: $card.address.postal_code ?? "")
    }
}

/// TextField that can be used to capture the Country for a card object to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTCardCountry: View {
    @EnvironmentObject var card: PaymentCard
    
    public var body: some View {
        TextField("Country", text: $card.address.country ?? "")
    }
}

/// Button that allows a payment to be tokenized once it has the necessary data (Card Number, Expiration Date, and CVV)
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTButton: View {
    @EnvironmentObject var card: PaymentCard
    @EnvironmentObject var envBuyer: Buyer
    @EnvironmentObject var PT: PayTheory
    
    var completion: (Result<TokenizationResponse, FailureResponse>) -> Void
    var amount: Int
    var text: String
    var buyer: Buyer?
    var fee_mode: FEE_MODE
    var tags: [String: Any]
    
    /// Button that allows a payment to be tokenized once it has the necessary data (Card Number, Expiration Date, and CVV)
    /// - Parameters:
    ///   - amount: Payment amount that should be charged to the card in cents.
    ///   - buyer: Optional buyer object that can pass Buyer Options for the transaction.
    ///   - fee_mode: optional param that defaults to .SURCHARGE if you don't declare it. Can also pass .SERVICE_FEE as a prop
    ///   - completion: Function that will handle the result of the tokenization response once it has been returned from the server.
    public init(amount: Int, buyer: Buyer? = nil, fee_mode: FEE_MODE = .SURCHARGE, text: String = "Confirm", tags: [String:Any] = [:], completion: @escaping (Result<TokenizationResponse, FailureResponse>) -> Void) {
        self.completion = completion
        self.amount = amount
        self.fee_mode = fee_mode
        self.tags = tags
        self.text = text
    }
    
    
    public var body: some View {
        Button(text) {
            if let identity = buyer {
                PT.tokenize(card: card, amount: amount, buyerOptions: identity, fee_mode: fee_mode, tags: tags, completion: completion)
            } else {
                PT.tokenize(card: card, amount: amount, buyerOptions: envBuyer, fee_mode: fee_mode, tags: tags, completion: completion)
            }
        }
        .disabled(card.isValid == false)
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
    @EnvironmentObject var PT: PayTheory

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group{
            content()
        }.environmentObject(PT.envCard)
        .environmentObject(PT.envBuyer)
        .environmentObject(PT.envAch)
    }

}

//These fields are for creating an identity to associate with a purchase if you want to capture customer information

/// TextField that can be used to capture the First Name for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerFirstName: View {
    @EnvironmentObject var identity: Buyer
    
   public var body: some View {
        TextField("First Name", text: $identity.first_name ?? "")
    }
}

/// TextField that can be used to capture the Last Name for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerLastName: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Last Name", text: $identity.last_name ?? "")
    }
}

/// TextField that can be used to capture the Phone for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerPhone: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Phone", text: $identity.phone ?? "")
    }
}

/// TextField that can be used to capture the Email for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerEmail: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Email", text: $identity.email ?? "")
    }
}

/// TextField that can be used to capture the Address Line 1 for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerLineOne: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Address Line 1", text: $identity.personal_address.line1 ?? "")
    }
}

/// TextField that can be used to capture the Address Line 2 for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerLineTwo: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Address Line 2", text: $identity.personal_address.line2 ?? "")
    }
}

/// TextField that can be used to capture the City for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerCity: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("City", text: $identity.personal_address.city ?? "")
    }
}

/// TextField that can be used to capture the State for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerState: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("State", text: $identity.personal_address.region ?? "")
    }
}

/// TextField that can be used to capture the Zip for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerZip: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Zip", text: $identity.personal_address.postal_code ?? "")
    }
}

/// TextField that can be used to capture the Country for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTBuyerCountry: View {
    @EnvironmentObject var identity: Buyer
    
    public var body: some View {
        TextField("Country", text: $identity.personal_address.country ?? "")
    }
}

/// TextField that can be used to capture the Country for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTAchAccountName: View {
    @EnvironmentObject var account: BankAccount
    public init(){
        
    }
    
    public var body: some View {
        TextField("Name on Account", text: $account.name)
    }
}

/// TextField that can be used to capture the Country for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTAchAccountNumber: View {
    @EnvironmentObject var account: BankAccount
    public init(){
        
    }
    
    public var body: some View {
        TextField("Account Number", text: $account.account_number)
    }
}

/// TextField that can be used to capture the Country for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTAchAccountType: View {
    @EnvironmentObject var account: BankAccount
    var types = ["Checking", "Savings"]
    public init(){
        
    }
    
    public var body: some View {
        Picker("Account Type", selection: $account.account_type){
            ForEach(0 ..< types.count){
                Text(self.types[$0])
            }
        }.pickerStyle(SegmentedPickerStyle())
    }
}

/// TextField that can be used to capture the Country for Buyer Options to be used in a Pay Theory payment
///
///  - Requires: Ancestor view must be wrapped in a PTForm
///
public struct PTAchBankCode: View {
    @EnvironmentObject var account: BankAccount
    public init(){
        
    }
    
    public var body: some View {
        TextField("Routing Number", text: $account.bank_code)
    }
}
