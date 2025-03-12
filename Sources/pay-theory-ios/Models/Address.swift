//
//  Address.swift
//  PayTheory
//
//  Created by Austin Zani on 10/1/24.
//

import Foundation

/// A structure representing a physical address.
///
/// `Address` is used to store and manage address information, including street lines,
/// city, country, region, and postal code. It conforms to `Codable` for easy serialization
/// and `Equatable` for comparison.
///
/// - Note: The `region` property is constrained to a maximum of 2 characters.
public struct Address: Codable, Equatable {
    /// The city of the address.
    public var city: String?
    
    /// The country of the address.
    public var country: String?
    
    /// The region (state or province) of the address.
    ///
    /// This property is limited to a maximum of 2 characters. If a value longer than
    /// 2 characters is assigned, it will retain the previous value.
    public var region: String? {
        didSet {
            if let unwrappedRegion = self.region, unwrappedRegion.count > 2 {
                region = oldValue
            }
        }
    }
    
    /// The first line of the street address.
    public var line1: String?
    
    /// The second line of the street address (optional).
    public var line2: String?
    
    /// The postal code (ZIP code) of the address.
    public var postalCode: String?
    
    private enum CodingKeys: String, CodingKey {
        case city
        case country
        case line1
        case line2
        case postalCode = "postal_code"
        case region
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(city, forKey: .city)
        try container.encode(country, forKey: .country)
        try container.encode(line1, forKey: .line1)
        try container.encode(line2, forKey: .line2)
        try container.encode(postalCode, forKey: .postalCode)
        try container.encode(region, forKey: .region)
    }
    
    /// Creates a new `Address` instance.
    ///
    /// - Parameters:
    ///   - line1: The first line of the street address.
    ///   - line2: The second line of the street address (if applicable).
    ///   - city: The city of the address.
    ///   - country: The country of the address.
    ///   - region: The region (state or province) of the address. Limited to 2 characters.
    ///   - postalCode: The postal code (ZIP code) of the address.
    ///
    /// - Returns: A new `Address` instance with the provided information.
    public init(line1: String? = nil,
                line2: String? = nil,
                city: String? = nil,
                country: String? = nil,
                region: String? = nil,
                postalCode: String? = nil) {
        self.city = city
        self.country = country
        self.line1 = line1
        self.line2 = line2
        self.postalCode = postalCode
        // Tryin the region to its first two characters if it is too long
        if let region {
            let trimmed = region.trimmingCharacters(in: .whitespacesAndNewlines)
            self.region = trimmed.count > 2 ? String(trimmed.prefix(2)) : trimmed
        }
    }
}
