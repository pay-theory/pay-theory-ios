//
//  PayTheory.swift
//  PayTheory
//
//  Created by Austin Zani on 11/3/20.
//

import Foundation

public class Buyer: ObservableObject, Codable, Equatable {
    public static func == (lhs: Buyer, rhs: Buyer) -> Bool {
        if lhs.phone == rhs.phone &&
        lhs.first_name == rhs.first_name &&
        lhs.last_name == rhs.last_name &&
        lhs.email == rhs.email &&
            lhs.personal_address == rhs.personal_address {
            return true
        }
        return false
    }
    
    @Published public var phone: String?
    @Published public var first_name: String?
    @Published public var last_name: String?
    @Published public var email: String?
    @Published public var personal_address: Address
    
    enum CodingKeys: CodingKey {
        case phone, first_name, last_name, email, personal_address
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phone, forKey: .phone)
        try container.encode(first_name, forKey: .first_name)
        try container.encode(last_name, forKey: .last_name)
        try container.encode(email, forKey: .email)
        try container.encode(personal_address, forKey: .personal_address)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? nil
        first_name = try container.decodeIfPresent(String.self, forKey: .first_name) ?? nil
        last_name = try container.decodeIfPresent(String.self, forKey: .last_name) ?? nil
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? nil
        personal_address = try container.decode(Address.self, forKey: .personal_address)
    }
    
    public init(first_name: String? = nil, last_name: String? = nil, email: String? = nil, phone: String? = nil, personal_address: Address = Address()) {
        self.email = email
        self.first_name = first_name
        self.last_name = last_name
        self.phone = phone
        self.personal_address = personal_address
    }
    
    func clear() {
        self.email = nil
        self.first_name = nil
        self.last_name = nil
        self.phone = nil
        self.personal_address = Address()
    }
}

func buyerToDictionary(buyer: Buyer) -> [String: Any] {
    var result: [String: Any] = [:]
    
    if let phone = buyer.phone {
        result["phone"] = phone
    }
    if let first_name = buyer.first_name {
        result["first_name"] = first_name
    }
    if let last_name = buyer.last_name {
        result["last_name"] = last_name
    }
    if let email = buyer.email {
        result["email"] = email
    }
    
    result["personal_address"] = addressToDictionary(address: buyer.personal_address)
    
    return result
}

class IdentityBody: Codable {
    var entity: Buyer
    
    init(entity: Buyer) {
        self.entity = entity
    }
}

class IdentityResponse: Codable, Equatable {
    static func == (lhs: IdentityResponse, rhs: IdentityResponse) -> Bool {
        if lhs.id == rhs.id &&
        lhs.application == rhs.application &&
        lhs.entity == rhs.entity &&
        lhs.created_at == rhs.created_at &&
            lhs.updated_at == rhs.updated_at {
            return true
        }
        
        return false
    }
    
    var id = ""
    var application = ""
    var entity = Buyer()
    var created_at = ""
    var updated_at = ""
    
    init() {
        
    }
}
