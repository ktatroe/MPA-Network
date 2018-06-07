//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


public typealias JSONObject = [String : Any]


/// Options for parsing and validating JSON using the `JSONParser` class.
public struct JSONParsingOptions: OptionSet {
    public let rawValue: Int

    /// No options set.
    public static let none = JSONParsingOptions(rawValue: 0)

    /// Allow empty values (will be converted to a default value when parsed).
    public static let allowEmpty = JSONParsingOptions(rawValue: 1)

    /// Allow value conversion; for example, if bare literal instead of requested array, convert to an array containing it.
    public static let allowConversion = JSONParsingOptions(rawValue: 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}


/**
 Normalizes values from JSON objects, with options for allowing for conversion from unexpected value
 types and missing values.
*/
open class JSONParser {
    public static func parseIdentifier(_ value: Any?, options: JSONParsingOptions = .none) -> String? {
        if let stringValue = JSONParser.parseString(value) {
            return stringValue.lowercased()
        }

        return nil
    }

    public static func parseString(_ value: Any?, options: JSONParsingOptions = .none) -> String? {
        if let stringValue = value as? String {
            return stringValue.stringByDecodingJavascriptEntities()
        }

        if options.contains(.allowConversion) {
            if let numberValue = value as? NSNumber {
                return String(describing: numberValue)
            }
        }

        if options.contains(.allowEmpty) {
            return ""
        }

        return nil
    }

    public static func parseInt(_ value: Any?, options: JSONParsingOptions = .none) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }

        if options.contains(.allowConversion) {
            if let numberValue = value as? NSNumber {
                return Int(truncating: numberValue)
            }

            if let stringValue = value as? String {
                return Int(stringValue)
            }
        }

        if options.contains(.allowEmpty) {
            return 0
        }

        return nil
    }

    public static func parseDouble(_ value: Any?, options: JSONParsingOptions = .none) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }

        if options.contains(.allowConversion) {
            if let numberValue = value as? NSNumber {
                return Double(truncating: numberValue)
            }

            if let stringValue = value as? String {
                return Double(stringValue)
            }
        }

        if options.contains(.allowEmpty) {
            return 0.0
        }

        return nil
    }

    public static func parseBool(_ value: Any?, options: JSONParsingOptions = .none) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }

        if options.contains(.allowConversion) {
            if let numberValue = value as? NSNumber {
                return Bool(truncating: numberValue)
            }

            if let stringValue = value as? String {
                if stringValue.lowercased() == "true" || stringValue == "1" {
                    return true
                }

                return false
            }
        }

        if options.contains(.allowEmpty) {
            return false
        }

        return nil
    }

    public static func parseArray(_ value: Any?, options: JSONParsingOptions = .none) -> [Any]? {
        if let arrayValue = value as? [Any] {
            return arrayValue
        }

        if let value = value {
            if let _ = value as? NSNull {
                if options.contains(.allowConversion) {
                    return [Any]()
                }
            }

            if options.contains(.allowConversion) {
                return [value]
            }
        }

        if options.contains(.allowEmpty) {
            return [Any]()
        }

        return nil
    }

    public static func parseObject(_ value: Any?, options: JSONParsingOptions = .none) -> JSONObject? {
        if let objectValue = value as? [String : Any] {
            return objectValue
        }

        if let value = value {
            if let _ = value as? NSNull {
                if options.contains(.allowConversion) {
                    return [String : Any]()
                }
            }
        }

        if options.contains(.allowEmpty) {
            return [String : Any]()
        }

        return nil
    }

    public static func parseISO8601Date(_ value: Any?, options: JSONParsingOptions = .none) -> Date? {
        if let dateString = JSONParser.parseString(value, options: options) {
            if let dateValue = Date.dateFromISO8601String(dateString) {
                return dateValue
            }
        }

        if options.contains(.allowEmpty) {
            return Date()
        }

        return nil
    }

    public static func parseDecimalNumber(_ value: Any?, options: JSONParsingOptions = .none) -> NSDecimalNumber? {
        if let decimalString = JSONParser.parseString(value, options: options) {
            return NSDecimalNumber(string: decimalString, locale: [NSLocale.Key.decimalSeparator: "."])
        }

        if options.contains(.allowEmpty) {
            return NSDecimalNumber.zero
        }

        return nil
    }
}

public protocol JSONParsing {
    func updateFromJSONRepresentation(_ data: JSONObject)

    static func isValidJSONRepresentation (_ data: JSONObject) -> Bool
}

extension String {
    func stringByDecodingJavascriptEntities() -> String {
        func decodeHexValue(_ string: String, base: Int32) -> Character? {
            let code = UInt32(strtoul(string, nil, base))

            return Character(UnicodeScalar(code)!)
        }

        func decodeEntity(_ entity: String) -> Character? {
            if entity.hasPrefix("\\x") || entity.hasPrefix("\\u") {
                return decodeHexValue(String(entity[entity.startIndex ..< entity.index(entity.startIndex, offsetBy: 2)]), base: 16)
            }

            return nil
        }

        var result = ""
        var position = startIndex

        let entityBeacons = ["\\x", "\\u"]

        for beacon in entityBeacons {
            while let entityRange = self.range(of: beacon, range: position ..< endIndex) {
                result += self[position ..< entityRange.lowerBound]
                position = entityRange.lowerBound

                let entityLength = (beacon == "\\u") ? 6 : 4
                let indexAtEntityEnd = self.index(position, offsetBy: entityLength)
                
                let entity = self[position ..< indexAtEntityEnd]

                if let decodedEntity = decodeEntity(String(entity)) {
                    result.append(decodedEntity)
                } else {
                    result.append(String(entity))
                }
                
                position = indexAtEntityEnd
            }
        }

        result += self[position ..< endIndex]

        return result
    }
}


extension Date {
    struct ISO8601Support {
        static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

            return formatter
        }()
    }

    public static func dateFromISO8601String(_ string: String) -> Date? {
        return ISO8601Support.formatter.date(from: string)
    }

    public var iso8601String: String { return ISO8601Support.formatter.string(from: self) }
}
