# PayTheory

[![CI Status](https://img.shields.io/travis/60404116/PayTheory.svg?style=flat)](https://travis-ci.org/60404116/PayTheory)
[![Version](https://img.shields.io/cocoapods/v/PayTheory.svg?style=flat)](https://cocoapods.org/pods/PayTheory)
[![License](https://img.shields.io/cocoapods/l/PayTheory.svg?style=flat)](https://cocoapods.org/pods/PayTheory)
[![Platform](https://img.shields.io/cocoapods/p/PayTheory.svg?style=flat)](https://cocoapods.org/pods/PayTheory)

## Requirements

Written in SwiftUI and requires iOS 14 for App Attestation

## Installation

PayTheory is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'PayTheory'
```

At the top of the view import PayTheory

```swift
import PayTheory
```

## Usage

Initialize a PayTheory element for handling state. It accepts the following arguments.
- **apiKey**: Your PayTheory merchant API Key
- **tags**: optional custom tags you can include to track purchases
- **environment**: tells the SDK if it should be working from a demo or production environment (**.DEMO** or **.PROD**). Defaults to **.DEMO**
- **fee_mode**: optionally set the fee mode.  By default **.SURCHARGE** mode is used **.SERVICE_FEE** mode is available only when enabled by Pay Theory **.SURCHARGE** mode applies a fee of 2.9% + $0.30 to be deducted from original amount **.SERVICE FEE** mode calculates a fee based on predetermined parameters  and adds it to the original amount

```swift
let apiKey = 'your-api-key'
let tags: [String: Any] = ["YOUR_TAG_KEY": "YOUR_TAG_VALUE"]

let pt = PayTheory(apiKey: apiKey, tags: tags, environment: .DEMO, fee_mode: .SURCHARGE)
```

The content view in which the PayTheory object will be used needs to be wrapped with the PTForm component. You should pass the PayTheory object as an EnvironmentObject to the PTForm.

```swift
let apiKey = 'your-api-key'
let tags: [String: Any] = ["YOUR_TAG_KEY": "YOUR_TAG_VALUE"]

let pt = PayTheory(apiKey: apiKey, tags: tags, environment: .DEMO, fee_mode: .SURCHARGE)

PTForm{
    ContentView()
}.EnvironmentObject(pt)
```
### Credit Card Text Fields

These custom text fields are what will be used to collect the card information for the transaction.

There are three required text fields to capture the info needed to initialize a card transaction

- Credit Card Number
- Credit Card Expiration
- Credit Card CVV

```swift
PTCardNumber()
PTExp()
PTCvv()
```

There are optional fields for capturing Billing Address and Name On Card

- Credit Card Name
- Credit Card Address Line One
- Credit Card Address Line Two
- Credit Card City
- Credit Card State
- Credit Card Zip
- Credit Card Country

```swift
PTCardName()
PTCardLineOne()
PTCardLineTwo()
PTCardCity()
PTCardState()
PTCardZip()
PTCardCountry()
```

### ACH Text Fields

These custom text fields are what will be used to collect the ACH information for the transaction.

All four text fields are required to capture the info needed to initialize an ACH transaction

- ACH Account Number
- ACH Account Type
- ACH Account Name
- ACH Routing Number

```swift
PTAchAccountName()
PTAchAccountNumber()
PTAchRoutingNumber()
PTAchAccountType()
```
### Buyer Options

You can optionally pass buyer information that will be tied to a transaction. All pieces of data are optional in the buyer object. 

One way to capture buyer options are to use text fields the same as you would for card details

- Buyer First Name
- Buyer Last Name
- Buyer Phone
- Buyer Email
- Buyer Address Line One
- Buyer Address Line Two
- Buyer City
- Buyer State
- Buyer Zip
- Buyer Country


```swift
PTBuyerFirstName()
PTBuyerLastName()
PTBuyerPhone()
PTBuyerEmail()
PTBuyerLineOne()
PTBuyerLineTwo()
PTBuyerCity()
PTBuyerState()
PTBuyerZip()
PTBuyerCountry()
```

Another option is to pass the info in as a **Buyer** object when initializing the payment.

```swift
let address = Address(line1: "123 Street St", line2: "Apt 12", city: "Somewhere", country: "USA", state: "OH", zip: "12345")
let buyer = Buyer(first_name: "Some", last_name: "Body", email: "somebody@gmail.com", phone: "555-555-5555", address: address)
```

### Pay Theory Button

This button component allows a transaction to be initialized. It will be disabled until it has the required data needed to initialize a transaction. It accepts a few arguments needed to initialize the payment.

 - **amount**: Payment amount that should be charged to the card in cents
 - **buyer**: Buyer that allows name, email, phone number, and address of the buyer to be associated with the payment. If Buyer Info is passed as an argument it will ignore the ones captured by the custom text fields
 - **completion**: Function that will handle the result of the call returning a dictionary **[String:Any]** or **Failure Response**


```swift
let amount = 1000
let buyer = Buyer(first_name: "Some", last_name: "Body", email: "somebody@gmail.com")

func completion(result: Result<[String: Any], FailureResponse>){
    switch result {
    case .success(let token):
            ...
        case .failure(let error):
            ...
        }
}

...
PTButton(amount: 5000, buyer: buyer, completion: completion)
```

### Capture or Cancel an Authorization

If the fee_mode is set to **.SERVICE_FEE** there is a confirmation step required. There are functions available to confirm or cancel the transaction after displaying the service fee to the user. The capture function accepts a completion handler for the response. To access these pull in the PayTheory object as an environment variable as shown below.

```swift
@EnvironmentObject var pt: PayTheory

func captureCompletion(result: Result<[String:Any], FailureResponse>){
    switch result {
    case .success(let completion):
        ...
    case .failure(let response):
        ...
    }
}


//To capture the transaction
    pt.capture(completion: captureCompletion)
    
//To cancel the transaction
    pt.cancel()

```

## Tokenization Response

When the necessary info is collected and the PTButton is clicked when fee_mode is set to **.SERVICE_FEE** the token details are returned as a dictionary **[String: Any]** with the following info:

*note that the service fee is included in amount*

```swift 
//Response for a card transaction
[
    "receipt_number": "pt-env-XXXXXX",
    "first_six": "XXXXXX", 
    "brand": "XXXXXXXXX", 
    "amount": 1000, 
    "convenience_fee": 195
]

//Response for an ACH transaction
[
    "receipt_number": "pt-env-XXXXXX",
    "last_four": "XXXX",
    "amount": 1000, 
    "convenience_fee": 195
]
```

## Completion Response

Once the PTButton is clicked and service_fee is set to **.SURCHARGE** or if the capture function is called after tokenization, a dictionary **[String: Any]** will be returned with the following info:

*note that the service fee is included in amount*

```swift 
//Response for a card transaction
[
   "receipt_number":"pt-env-XXXXXX",
    "last_four": "XXXX",
    "brand": "XXXXXXXXX",
    "created_at":"YYYY-MM-DDTHH:MM:SS.ssZ",
    "amount": 999,
    "service_fee": 195,
    "state":"SUCCEEDED",
    "tags": ["pay-theory-environment":"env","pt-number":"pt-env-XXXXXX", "YOUR_TAG_KEY": "YOUR_TAG_VALUE"]
]

//Response for an ACH transaction
[
   "receipt_number":"pt-env-XXXXXX",
    "last_four": "XXXX",
    "created_at":"YYYY-MM-DDTHH:MM:SS.ssZ",
    "amount": 999,
    "service_fee": 195,
    "state":"SUCCEEDED",
    "tags": ["pay-theory-environment":"env","pt-number":"pt-env-XXXXXX", "YOUR_TAG_KEY": "YOUR_TAG_VALUE"]
]
```

## Failure Response

If a failure or decline occurs during the transaction, a FailureResponse object will be returned with the following info:

*note that the service fee is included in amount*

```swift 
class FailureResponse {
    var receipt_number: String
    var last_four: String
    var brand: String? //Will not include the brand if it is an ACH transaction
    var state = "FAILURE"
    var type: String
}
```

## Styling the text fields and button

To style the text fields and button you can simply treat them as any other standard SwiftUI text field to style.

```swift
struct TextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(15)
            .font(Font.system(size: 15, weight: .medium, design: .serif))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
    }
}

extension View {
    func textFieldStyle() -> some View {
        self.modifier(TextField())
    }
}

PTCardName().textFieldStyle()
PTCardNumber().textFieldStyle()
PTExp().textFieldStyle()
PTCvv().textFieldStyle()
```


## Author

60404116, support@paytheory.com

## License

PayTheory is available under the MIT license. See the LICENSE file for more info.
