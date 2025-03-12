//
//  Level3DataSummary.swift
//  PayTheory
//
//  Created by Austin Zani on 10/1/24.
//

/// Represents the type of tax indicator for a transaction.
public enum TaxIndicatorType: String, Encodable {
    /// Indicates that a tax amount has been provided for the transaction.
    case taxAmountProvided = "TAX_AMOUNT_PROVIDED"
    
    /// Indicates that the transaction is not taxable.
    case notTaxable = "NOT_TAXABLE"
    
    /// Indicates that no tax information has been provided for the transaction.
    case noTaxInfoProvided = "NO_TAX_INFO_PROVIDED"
}

/// A structure representing Level 3 data summary for a transaction.
///
/// Level 3 data provides detailed information about a transaction, typically used in
/// business-to-business or government purchases. This struct encapsulates various
/// aspects of the transaction such as tax information, purchase identifiers, and
/// shipping details.
public struct Level3DataSummary: Encodable {
    /// The tax amount for the transaction.
    var taxAmt: Int?
    
    /// The tax indicator type for the transaction.
    var taxInd: TaxIndicatorType?
    
    /// A unique identifier for the purchase.
    var purchIdfr: String?
    
    /// The order number associated with the transaction.
    var orderNum: String?
    
    /// The discount amount applied to the transaction.
    var discntAmt: Int?
    
    /// The freight amount for the transaction.
    var frghtAmt: Int?
    
    /// The duty amount for the transaction, if applicable.
    var dutyAmt: Int?
    
    /// The destination postal code for the shipment.
    var destPostalCode: String?
    
    /// An array of product descriptions related to the transaction.
    var prodDesc: [String]?
    
    /// Creates a new instance of `Level3DataSummary`.
    ///
    /// - Parameters:
    ///   - taxAmt: The tax amount for the transaction.
    ///   - taxInd: The tax indicator type for the transaction.
    ///   - purchIdfr: A unique identifier for the purchase.
    ///   - orderNum: The order number associated with the transaction.
    ///   - discntAmt: The discount amount applied to the transaction.
    ///   - frghtAmt: The freight amount for the transaction.
    ///   - dutyAmt: The duty amount for the transaction, if applicable.
    ///   - destPostalCode: The destination postal code for the shipment.
    ///   - prodDesc: An array of product descriptions related to the transaction.
    public init(taxAmt: Int? = nil,
                taxInd: TaxIndicatorType? = nil,
                purchIdfr: String? = nil,
                orderNum: String? = nil,
                discntAmt: Int? = nil,
                frghtAmt: Int? = nil,
                dutyAmt: Int? = nil,
                destPostalCode: String? = nil,
                prodDesc: [String]? = nil) {
        self.taxAmt = taxAmt
        self.taxInd = taxInd
        self.purchIdfr = purchIdfr
        self.orderNum = orderNum
        self.discntAmt = discntAmt
        self.frghtAmt = frghtAmt
        self.dutyAmt = dutyAmt
        self.destPostalCode = destPostalCode
        self.prodDesc = prodDesc
    }
    
    /// Coding keys for encoding and decoding `Level3DataSummary`.
    ///
    /// These keys map the struct's properties to the keys used in JSON encoding.
    enum CodingKeys: String, CodingKey {
        case taxAmt = "tax_amt"
        case taxInd = "tax_ind"
        case purchIdfr = "purch_idfr"
        case orderNum = "order_num"
        case discntAmt = "discnt_amt"
        case frghtAmt = "frght_amt"
        case dutyAmt = "duty_amt"
        case destPostalCode = "dest_postal_code"
        case prodDesc = "prod_desc"
    }
    
    /// Encodes this instance of `Level3DataSummary`.
    ///
    /// This method is automatically called when encoding an instance of `Level3DataSummary`.
    /// It ensures that all properties are encoded with their corresponding coding keys.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if any values are invalid for the given encoder's format.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taxAmt, forKey: .taxAmt)
        try container.encode(taxInd, forKey: .taxInd)
        try container.encode(purchIdfr, forKey: .purchIdfr)
        try container.encode(orderNum, forKey: .orderNum)
        try container.encode(discntAmt, forKey: .discntAmt)
        try container.encode(frghtAmt, forKey: .frghtAmt)
        try container.encode(dutyAmt, forKey: .dutyAmt)
        try container.encode(destPostalCode, forKey: .destPostalCode)
        try container.encode(prodDesc, forKey: .prodDesc)
    }
}
