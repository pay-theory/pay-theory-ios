//
//  Functions.swift
//  PayTheory
//
//  Created by Austin Zani on 3/15/21.
//

import Foundation
import Sodium

extension Data {
    init?(hexString: String) {
      let len = hexString.count / 2
      var data = Data(capacity: len)
      var index = hexString.startIndex
      for _ in 0..<len {
        let offset = hexString.index(index, offsetBy: 2)
        let bytes = hexString[index..<offset]
        if var num = UInt8(bytes, radix: 16) {
          data.append(&num, count: 1)
        } else {
          return nil
        }
        index = offset
      }
      self = data
    }
    /// Hexadecimal string representation of `Data` object.
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}

func generateUUID() -> String {
    return UUID().uuidString
}

func splitDate(_ dateString: String) -> (month: String, year: String) {
    // Check if the string is empty
    guard !dateString.isEmpty else {
        return ("", "")
    }

    // Split the string by "/"
    let components = dateString.split(separator: "/", maxSplits: 1)
    
    // If there's no "/", assume the entire string is the month
    if components.count == 1 {
        return (String(components[0]), "")
    }
    
    // If we have both month and year
    if components.count == 2 {
        let year = String(components[1])
        // If the year is 2 characters add the leading 20
        if year.count == 2 {
            return (String(components[0]), "20\(year)")
        }
        return (String(components[0]), "")
    }
    
    // If we reach here, the format is unexpected
    return ("", "")
}

// MARK: - Functions used to convert data to and from JSON

func convertStringToDictionary(text: String) -> [String: AnyObject]? {
    if let data = text.data(using: .utf8) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: AnyObject]
            return json
        } catch {
            print("Something went wrong decoding repsonse")
        }
    }
    return nil
}

func stringify(jsonDictionary: [String: Any]) -> String {
  do {
    let data = try JSONSerialization.data(withJSONObject: jsonDictionary, options: .prettyPrinted)
    return String(data: data, encoding: String.Encoding.utf8) ?? ""
  } catch {
    return ""
  }
}

// First, let's define a custom encoding strategy
class NullEncodingStrategy {
    static let nullEncoded = JSONEncoder.KeyEncodingStrategy.custom { keys in
        NullEncodableKey(keys.last!)
    }
}

// This struct will handle the actual encoding
struct NullEncodableKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init(_ key: CodingKey) {
        self.stringValue = key.stringValue
        self.intValue = key.intValue
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

func convertToJSONString<T: Encodable>(_ object: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.keyEncodingStrategy = NullEncodingStrategy.nullEncoded
    do {
        let jsonData = try encoder.encode(object)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
    } catch {
        print("Error encoding to JSON: \(error)")
    }
    return ""
}

func convertBytesToString(bytes: Bytes) -> String {
    let data = NSData(bytes: bytes, length: bytes.count)
    let base64Data = data.base64EncodedData(options: .endLineWithLineFeed)
    let newData = NSData(base64Encoded: base64Data, options: .ignoreUnknownCharacters) ?? NSData()
    return newData.base64EncodedString()
}

func convertStringToByte(string: String) -> Bytes {
    return [UInt8](NSData(base64Encoded: string, options: NSData.Base64DecodingOptions(rawValue: 0)) ?? NSData())
}

func parseError(errors: [String: AnyObject]) -> String {
    var type = ""
    var message = ""
    let field = errors["_embedded"] as? [String: AnyObject]
    let errors = field?["errors"] as? [[String: AnyObject]]
    if let initialType = errors?[0]["field"] {
        type = initialType as? String ?? ""
    }
    if let initialMessage = errors?[0]["message"] {
        message = initialMessage as? String ?? ""
    }
    
    return "\(type) \(message)"
}

// MARK: - Functions used to format strings for a Text Input

func insertCreditCardSpaces(_ string: String) -> String {
    // Mapping of card prefix to pattern is taken from
    // https://baymard.com/checkout-usability/credit-card-patterns

    // UATP cards have 4-5-6 (XXXX-XXXXX-XXXXXX) format
    let is456 = string.hasPrefix("1")

    // These prefixes reliably indicate either a 4-6-5 or 4-6-4 card. We treat all these
    // as 4-6-5-4 to err on the side of always letting the user type more digits.
    let is465 = [
        // Amex
        "34", "37",

        // Diners Club
        "300", "301", "302", "303", "304", "305", "309", "36", "38", "39"
    ].contains { string.hasPrefix($0) }

    // In all other cases, assume 4-4-4-4-3.
    // This won't always be correct; for instance, Maestro has 4-4-5 cards according
    // to https://baymard.com/checkout-usability/credit-card-patterns, but I don't
    // know what prefixes identify particular formats.
    let is4444 = !(is456 || is465)

    var stringWithAddedSpaces = ""

    for index in 0..<string.count {
        let needs465Spacing = (is465 && (index == 4 || index == 10))
        let needs456Spacing = (is456 && (index == 4 || index == 9))
        let needs4444Spacing = (is4444 && index > 0 && (index % 4) == 0 && index < 13)

        if needs465Spacing || needs456Spacing || needs4444Spacing {
            stringWithAddedSpaces.append(" ")
        }

        let characterToAdd = string[string.index(string.startIndex, offsetBy: index)]
        if ((is456 || is465) && index <= 14) || (is4444 && index <= 15) {
            stringWithAddedSpaces.append(characterToAdd)
        }
    }

    return stringWithAddedSpaces
}

func formatExpirationDate(_ input: String) -> String {
    // Remove all non-numeric characters from the input
    var cleaned = input.filter { $0.isNumber }
    var formatted = ""
    
    if cleaned.count > 0 {
        // Extract the month from the first two characters (if available)
        let month = Int(cleaned.prefix(2)) ?? 0
        
        if month > 12 {
            // If month is greater than 12, take the first digit and prepend a 0
            formatted = "0\(cleaned.prefix(1))"
            cleaned = "0\(cleaned)" // Update cleaned string for year formatting
        } else if month == 0 {
            // If month is 0, set it to "0"
            formatted = "0"
        } else if cleaned.count > 1 {
            // For valid months with more than one digit
            formatted = month < 10 ? "0\(month)" : "\(month)"
        } else {
            // For single digit input, don't add leading zero yet
            formatted = "\(month)"
        }
        
        if cleaned.count > 2 {
            // Add slash after month if there's input for year
            formatted += "/"
            // Take up to two digits for the year
            let year = String(cleaned.suffix(cleaned.count - 2).prefix(2))
            formatted += year
        }
    }
    
    return formatted
}

func formatDigitTextField(_ value: String, maxLength: Int) -> String {
    // Filter out non-numeric characters
    let filtered = value.filter { $0.isNumber }
    
    // Limit to 4 digits
    return String(filtered.prefix(maxLength))
}

// MARK: - Functions used to check if values are valid for Payment Methods

func isValidEmail(value: String) -> Bool {
            let emailRegex = "(?:[\\p{L}0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[\\p{L}0-9!#$%\\&'*+/=?\\^_`{|}" +
                "~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\" +
                "x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[\\p{L}0-9](?:[a-" +
                "z0-9-]*[\\p{L}0-9])?\\.)+[\\p{L}0-9](?:[\\p{L}0-9-]*[\\p{L}0-9])?|\\[(?:(?:25[0-5" +
                "]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-" +
                "9][0-9]?|[\\p{L}0-9-]*[\\p{L}0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21" +
                "-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"
            let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            let result = emailTest.evaluate(with: value)
            return result
        }

func isValidPhone(value: String) -> Bool {
            let phoneRegex = "^(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}$"
            let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
            let result = phoneTest.evaluate(with: value)
            return result
        }


func isValidExpDate(month: String, year: String) -> Bool {
    if year.count != 4 {
        return false
    }

    let currentDate = Date()
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: currentDate)
    let currentMonth = calendar.component(.month, from: currentDate)
    
    if let yeared = Int(year) {
        if yeared < currentYear {
            // Expired because past exp year
            return false
        }
        if let monthed = Int(month) {
            if monthed < currentMonth && yeared == currentYear {
                // Expired because month is previous month this year
                return false
            }
        } else {
            // Could not parse month to Int
            return false
        }
    } else {
        // Could not parse year to Int
        return false
    }

    return true
}

func isValidCardNumber(cardString: String) -> Bool {
    let noSpaces = String(cardString.filter { !" \n\t\r".contains($0) })
    if noSpaces.count < 13 {
        return false
    }
    
    var sum = 0
    let digitStrings = noSpaces.reversed().map { String($0) }

    for tuple in digitStrings.enumerated() {
        if let digit = Int(tuple.element) {
            let odd = tuple.offset % 2 == 1

            switch (odd, digit) {
            case (true, 9):
                sum += 9
            case (true, 0...8):
                sum += (digit * 2) % 9
            default:
                sum += digit
            }
        } else {
            return false
        }
    }
    return sum % 10 == 0
}

func isValidRoutingNumber(code: String) -> Bool {
    if code.count != 9 {
        return false
    }
    
    var number = 0
    for num in stride(from: 0, to: code.count, by: 3) {
        if let first = Int(code[num]) {
            number += (first * 3)
        } else {
            return false
        }
        
        if let second = Int(code[num + 1]) {
            number += (second * 7)
        } else {
            return false
        }
        
        if let third = Int(code[num + 2]) {
            number += (third * 1)
        } else {
            return false
        }
    }
    
    return number > 0 && number % 10 == 0
}

func isValidPostalCode(value: String) -> Bool {
    if value == "" {
        return false
    }
    for regex in postalRegexList {
        let zipTest = NSPredicate(format: "SELF MATCHES %@", regex[1])
        let evaluated = zipTest.evaluate(with: value)
        if evaluated {
            return true
        }
    }
    
    return false
}


// Got list from https://github.com/melwynfurtado/postcode-validator/blob/master/src/postcode-regexes.ts
let postalRegexList: [[String]] = [
    ["UK",
     "^([A-Z]){1}([0-9][0-9]|[0-9]|[A-Z][0-9][A-Z]|[A-Z][0-9][0-9]|[A-Z][0-9]|[0-9][A-Z]){1}([ ])?([0-9][A-z][A-z]){1}$i"
    ],
    ["GB",
     "^([A-Z]){1}([0-9][0-9]|[0-9]|[A-Z][0-9][A-Z]|[A-Z][0-9][0-9]|[A-Z][0-9]|[0-9][A-Z]){1}([ ])?([0-9][A-z][A-z]){1}$i"
    ],
    ["JE", "^JE\\d[\\dA-Z]?[ ]?\\d[ABD-HJLN-UW-Z]{2}$"],
    ["GG", "^GY\\d[\\dA-Z]?[ ]?\\d[ABD-HJLN-UW-Z]{2}$"],
    ["IM", "^IM\\d[\\dA-Z]?[ ]?\\d[ABD-HJLN-UW-Z]{2}$"],
    ["US", "^([0-9]{5})(?:-([0-9]{4}))?$"],
    ["CA", "^([ABCEGHJKLMNPRSTVXY][0-9][ABCEGHJKLMNPRSTVWXYZ])\\s*([0-9][ABCEGHJKLMNPRSTVWXYZ][0-9])$i"],
    ["IE", "^([AC-FHKNPRTV-Y][0-9]{2}|D6W)[ -]?[0-9AC-FHKNPRTV-Y]{4}$"],
    ["DE", "^\\d{5}$"],
    ["JP", "^\\d{3}-\\d{4}$"],
    ["FR", "^\\d{2}[ ]?\\d{3}$"],
    ["AU", "^\\d{4}$"],
    ["IT", "^\\d{5}$"],
    ["CH", "^\\d{4}$"],
    ["AT", "^(?!0)\\d{4}$"],
    ["ES", "^(?:0[1-9]|[1-4]\\d|5[0-2])\\d{3}$"],
    ["NL", "^\\d{4}[ ]?[A-Z]{2}$"],
    ["BE", "^\\d{4}$"],
    ["DK", "^\\d{4}$"],
    ["SE", "^(SE-)?\\d{3}[ ]?\\d{2}$"],
    ["NO", "^\\d{4}$"],
    ["BR", "^\\d{5}[\\-]?\\d{3}$"],
    ["PT", "^\\d{4}([\\-]\\d{3})?$"],
    ["FI", "^(FI-|AX-)?\\d{5}$"],
    ["AX", "^22\\d{3}$"],
    ["KR", "^\\d{5}$"],
    ["CN", "^\\d{6}$"],
    ["TW", "^\\d{3}(\\d{2})?$"],
    ["SG", "^\\d{6}$"],
    ["DZ", "^\\d{5}$"],
    ["AD", "^AD\\d{3}$"],
    ["AR", "^([A-HJ-NP-Z])?\\d{4}([A-Z]{3})?$"],
    ["AM", "^(37)?\\d{4}$"],
    ["AZ", "^\\d{4}$"],
    ["BH", "^((1[0-2]|[2-9])\\d{2})?$" ],
    ["BD", "^\\d{4}$"],
    ["BB", "^(BB\\d{5})?$"],
    ["BY", "^\\d{6}$"],
    ["BM", "^[A-Z]{2}[ ]?[A-Z0-9]{2}$"],
    [
        "BA",
        "^\\d{5}$"
    ],
    [
        "IO",
        "^BBND 1ZZ$"
    ],
    [
        "BN",
        "^[A-Z]{2}[ ]?\\d{4}$"
    ],
    [
        "BG",
        "^\\d{4}$"
    ],
    [
        "KH",
        "^\\d{5}$"
    ],
    [
        "CV",
        "^\\d{4}$"
    ],
    [
        "CL",
        "^\\d{7}$"
    ],
    [
        "CR",
        "^(\\d{4,5}|\\d{3}-\\d{4})$"
    ],
    [
        "HR",
        "^(HR-)?\\d{5}$"
    ],
    [
        "CY",
        "^\\d{4}$"
    ],
    [
        "CZ",
        "^\\d{3}[ ]?\\d{2}$"
    ],
    [
        "DO",
        "^\\d{5}$"
    ],
    [
        "EC",
        "^([A-Z]\\d{4}[A-Z]|(?:[A-Z]{2})?\\d{6})?$"
    ],
    [
        "EG",
        "^\\d{5}$"
    ],
    [
        "EE",
        "^\\d{5}$"
    ],
    [
        "FO",
        "^\\d{3}$"
    ],
    [
        "GE",
        "^\\d{4}$"
    ],
    [
        "GR",
        "^\\d{3}[ ]?\\d{2}$"
    ],
    [
        "GL",
        "^39\\d{2}$"
    ],
    [
        "GT",
        "^\\d{5}$"
    ],
    [
        "HT",
        "^\\d{4}$"
    ],
    [
        "HN",
        "^(?:\\d{5})?$"
    ],
    [
        "HU",
        "^\\d{4}$"
    ],
    [
        "IS",
        "^\\d{3}$"
    ],
    [
        "IN",
        "^\\d{6}$"
    ],
    [
        "ID",
        "^\\d{5}$"
    ],
    [
        "IL",
        "^\\d{5,7}$"
    ],
    [
        "JO",
        "^\\d{5}$"
    ],
    [
        "KZ",
        "^\\d{6}$"
    ],
    [
        "KE",
        "^\\d{5}$"
    ],
    [
        "KW",
        "^\\d{5}$"
    ],
    [
        "LA",
        "^\\d{5}$"
    ],
    [
        "LV",
        "^(LV-)?\\d{4}$"
    ],
    [
        "LB",
        "^(\\d{4}([ ]?\\d{4})?)?$"
    ],
    [
        "LI",
        "^(948[5-9])|(949[0-7])$"
    ],
    [
        "LT",
        "^(LT-)?\\d{5}$"
    ],
    [
        "LU",
        "^(L-)?\\d{4}$"
    ],
    [
        "MK",
        "^\\d{4}$"
    ],
    [
        "MY",
        "^\\d{5}$"
    ],
    [
        "MV",
        "^\\d{5}$"
    ],
    [
        "MT",
        "^[A-Z]{3}[ ]?\\d{2,4}$"
    ],
    [
        "MU",
        "^((\\d|[A-Z])\\d{4})?$"
    ],
    [
        "MX",
        "^\\d{5}$"
    ],
    [
        "MD",
        "^\\d{4}$"
    ],
    [
        "MC",
        "^980\\d{2}$"
    ],
    [
        "MA",
        "^\\d{5}$"
    ],
    [
        "NP",
        "^\\d{5}$"
    ],
    [
        "NZ",
        "^\\d{4}$"
    ],
    [
        "NI",
        "^((\\d{4}-)?\\d{3}-\\d{3}(-\\d{1})?)?$"
    ],
    [
        "NG",
        "^(\\d{6})?$"
    ],
    [
        "OM",
        "^(PC )?\\d{3}$"
    ],
    [
        "PA",
        "^\\d{4}$"
    ],
    [
        "PK",
        "^\\d{5}$"
    ],
    [
        "PY",
        "^\\d{4}$"
    ],
    [
        "PH",
        "^\\d{4}$"
    ],
    [
        "PL",
        "^\\d{2}-\\d{3}$"
    ],
    [
        "PR",
        "^00[679]\\d{2}([ \\-]\\d{4})?$"
    ],
    [
        "RO",
        "^\\d{6}$"
    ],
    [
        "RU",
        "^\\d{6}$"
    ],
    [
        "SM",
        "^4789\\d$"
    ],
    [
        "SA",
        "^\\d{5}$"
    ],
    [
        "SN",
        "^\\d{5}$"
    ],
    [
        "SK",
        "^\\d{3}[ ]?\\d{2}$"
    ],
    [
        "SI",
        "^(SI-)?\\d{4}$"
    ],
    [
        "ZA",
        "^\\d{4}$"
    ],
    [
        "LK",
        "^\\d{5}$"
    ],
    [
        "TJ",
        "^\\d{6}$"
    ],
    [
        "TH",
        "^\\d{5}$"
    ],
    [
        "TN",
        "^\\d{4}$"
    ],
    [
        "TR",
        "^\\d{5}$"
    ],
    [
        "TM",
        "^\\d{6}$"
    ],
    [
        "UA",
        "^\\d{5}$"
    ],
    [
        "UY",
        "^\\d{5}$"
    ],
    [
        "UZ",
        "^\\d{6}$"
    ],
    [
        "VA",
        "^00120$"
    ],
    [
        "VE",
        "^\\d{4}$"
    ],
    [
        "ZM",
        "^\\d{5}$"
    ],
    [
        "AS",
        "^96799$"
    ],
    [
        "CC",
        "^6799$"
    ],
    [
        "CK",
        "^\\d{4}$"
    ],
    [
        "RS",
        "^\\d{5,6}$"
    ],
    [
        "ME",
        "^8\\d{4}$"
    ],
    [
        "CS",
        "^\\d{5}$"
    ],
    [
        "YU",
        "^\\d{5}$"
    ],
    [
        "CX",
        "^6798$"
    ],
    [
        "ET",
        "^\\d{4}$"
    ],
    [
        "FK",
        "^FIQQ 1ZZ$"
    ],
    [
        "NF",
        "^2899$"
    ],
    [
        "FM",
        "^(9694[1-4])([ \\-]\\d{4})?$"
    ],
    [
        "GF",
        "^9[78]3\\d{2}$"
    ],
    [
        "GN",
        "^\\d{3}$"
    ],
    [
        "GP",
        "^9[78][01]\\d{2}$"
    ],
    [
        "GS",
        "^SIQQ 1ZZ$"
    ],
    [
        "GU",
        "^969[123]\\d([ \\-]\\d{4})?$"
    ],
    [
        "GW",
        "^\\d{4}$"
    ],
    [
        "HM",
        "^\\d{4}$"
    ],
    [
        "IQ",
        "^\\d{5}$"
    ],
    [
        "KG",
        "^\\d{6}$"
    ],
    [
        "LR",
        "^\\d{4}$"
    ],
    [
        "LS",
        "^\\d{3}$"
    ],
    [
        "MG",
        "^\\d{3}$"
    ],
    [
        "MH",
        "^969[67]\\d([ \\-]\\d{4})?$"
    ],
    [
        "MN",
        "^\\d{6}$"
    ],
    [
        "MP",
        "^9695[012]([ \\-]\\d{4})?$"
    ],
    [
        "MQ",
        "^9[78]2\\d{2}$"
    ],
    [
        "NC",
        "^988\\d{2}$"
    ],
    [
        "NE",
        "^\\d{4}$"
    ],
    [
        "VI",
        "^008(([0-4]\\d)|(5[01]))([ \\-]\\d{4})?$"
    ],
    [
        "VN",
        "^\\d{6}$"
    ],
    [
        "PF",
        "^987\\d{2}$"
    ],
    [
        "PG",
        "^\\d{3}$"
    ],
    [
        "PM",
        "^9[78]5\\d{2}$"
    ],
    [
        "PN",
        "^PCRN 1ZZ$"
    ],
    [
        "PW",
        "^96940$"
    ],
    [
        "RE",
        "^9[78]4\\d{2}$"
    ],
    [
        "SH",
        "^(ASCN|STHL) 1ZZ$"
    ],
    [
        "SJ",
        "^\\d{4}$"
    ],
    [
        "SO",
        "^\\d{5}$"
    ],
    [
        "SZ",
        "^[HLMS]\\d{3}$"
    ],
    [
        "TC",
        "^TKCA 1ZZ$"
    ],
    [
        "WF",
        "^986\\d{2}$"
    ],
    [
        "XK",
        "^\\d{5}$"
    ],
    [
        "YT",
        "^976\\d{2}$"
    ]
]
