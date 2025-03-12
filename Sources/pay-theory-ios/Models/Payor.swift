//
//  PayorFields.swift
//  PayTheory
//
//  Created by Austin Zani on 3/15/21.
//
import SwiftUI
import Foundation

/// Represents a payor in the PayTheory system.
///
/// This struct encapsulates information about an individual who is making a payment,
/// including personal details and address information.
public struct Payor: Codable {
    /// The phone number of the payor.
    public var phone: String?
    
    /// The first name of the payor.
    public var firstName: String?
    
    /// The last name of the payor.
    public var lastName: String?
    
    /// The email address of the payor.
    public var email: String?
    
    /// The personal address of the payor.
    public var personalAddress: Address

    /// Initializes a new instance of `Payor`.
    ///
    /// - Parameters:
    ///   - firstName: The first name of the payor. Defaults to `nil`.
    ///   - lastName: The last name of the payor. Defaults to `nil`.
    ///   - email: The email address of the payor. Defaults to `nil`.
    ///   - phone: The phone number of the payor. Defaults to `nil`.
    ///   - personalAddress: The personal address of the payor. Defaults to an empty `Address` instance.
    public init(firstName: String? = nil,
                lastName: String? = nil,
                email: String? = nil,
                phone: String? = nil,
                personalAddress: Address = Address()) {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.personalAddress = personalAddress
    }

    /// Clears all information in the `Payor` instance.
    ///
    /// This method resets all properties to their default values:
    /// - `nil` for optional String properties
    /// - A new, empty `Address` instance for `personalAddress`
    public mutating func clear() {
        self.email = nil
        self.firstName = nil
        self.lastName = nil
        self.phone = nil
        self.personalAddress = Address()
    }
    
    /// Coding keys for `Payor`.
    ///
    /// These keys are used for encoding and decoding the `Payor` struct,
    /// mapping the struct's properties to keys used in JSON representation.
    private enum CodingKeys: String, CodingKey {
        case phone
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case personalAddress = "personal_address"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.phone, forKey: .phone)
        try container.encode(self.firstName, forKey: .firstName)
        try container.encode(self.lastName, forKey: .lastName)
        try container.encode(self.email, forKey: .email)
        try container.encode(self.personalAddress, forKey: .personalAddress)
    }
}