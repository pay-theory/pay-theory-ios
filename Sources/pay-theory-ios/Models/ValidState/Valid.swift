//
//  Valid.swift
//  PayTheory
//
//  Created by Austin Zani on 7/23/21.
//

/// A protocol that defines properties for validating and checking the emptiness of an object.
///
/// Types conforming to `ValidAndEmpty` must provide implementations for `isValid` and `isEmpty` properties.
/// This protocol is useful for objects that need to be validated and can be in an empty state,
/// such as form fields, data models, or any other type where both validity and presence of data are relevant.
public protocol ValidAndEmpty {
    /// Indicates whether the object is in a valid state.
    ///
    /// Implementers should define their own criteria for validity. This could involve
    /// checking data formats, ranges, or any other relevant business logic.
    ///
    /// - Returns: `true` if the object is considered valid, `false` otherwise.
    var isValid: Bool { get }
    
    /// Indicates whether the object is considered empty.
    ///
    /// The definition of "empty" may vary depending on the type. For example:
    /// - For strings, it might mean having no characters.
    /// - For collections, it might mean having no elements.
    /// - For custom types, it might mean all properties are in their default state.
    ///
    /// - Returns: `true` if the object is considered empty, `false` otherwise.
    var isEmpty: Bool { get }
}
