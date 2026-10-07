import Foundation

nonisolated enum AgeUtils {
    /// Converts an optional age input and unit to months.
    /// Returns nil for unknown or invalid input, including values that exceed the supported range.
    static func months(from input: Int?, unit: AgeUnit) -> Int? {
        guard let value = validateAndConvert(input, unit: unit) else {
            #if DEBUG
            print("[AgeUtils] months(from: \(String(describing: input)), unit: \(unit)) -> nil")
            #endif
            return nil
        }

        #if DEBUG
        print("[AgeUtils] months(from: \(String(describing: input)), unit: \(unit)) -> \(value)")
        #endif
        return value
    }
    
    /// Validates age input, returning nil for invalid values.
    /// - Parameter input: The age value to validate
    /// - Returns: The validated age or nil if invalid (0, negative, or unreasonably large)
    static func validateAge(_ input: Int?) -> Int? {
        guard let value = input else {
            #if DEBUG
            print("[AgeUtils] validateAge(nil) -> nil")
            #endif
            return nil
        }
        // Reject 0, negative values, or ages over 50 years (600 months)
        guard value > 0 && value <= 600 else {
            #if DEBUG
            print("[AgeUtils] validateAge(\\(value)) -> nil (out of bounds)")
            #endif
            return nil
        }
        #if DEBUG
        print("[AgeUtils] validateAge(\\(value)) -> \\(value)")
        #endif
        return value
    }
    
    /// Validates and converts age input in the specified unit to months.
    /// - Parameters:
    ///   - input: The age value to validate and convert
    ///   - unit: The unit of the age (years or months)
    /// - Returns: The age in months or nil if invalid
    static func validateAndConvert(_ input: Int?, unit: AgeUnit) -> Int? {
        guard let value = input else { return nil }
        guard value > 0 else { return nil }
        
        let months: Int
        if unit == .years {
            guard value <= 50 else { return nil }
            months = value * 12
        } else {
            months = value
        }
        // Ensure converted value doesn't exceed 600 months (50 years)
        guard months <= 600 else { return nil }
        
        return months
    }
}
