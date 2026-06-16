import Foundation

/// Shared client-side input validation used across registration, profile editing,
/// and password-reset screens so the rules and error messages stay consistent.
///
/// Each `…Error` helper returns `nil` when the value is valid, or a user-friendly
/// message when it isn't. Backend validation still applies; this catches bad input
/// early with clear messaging.
enum ValidationUtils {

    // MARK: - Name

    /// Allows letters (including accented), spaces, hyphens, apostrophes and periods.
    /// Rejects digits and other symbols (e.g. `_ ! $ %`).
    static func nameError(_ name: String, fieldName: String = "Name") -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "\(fieldName) is required" }
        if trimmed.range(of: "^[\\p{L} .'-]+$", options: .regularExpression) == nil {
            return "\(fieldName) can only contain letters, spaces, hyphens (-) and apostrophes (')"
        }
        return nil
    }

    // MARK: - Email

    static func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    static func emailError(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Email is required" }
        if !isValidEmail(trimmed) { return "Enter a valid email address" }
        return nil
    }

    // MARK: - Phone

    /// Validates NZ phone numbers. Pass `required: false` for optional fields — an empty
    /// value then returns `nil` (valid). Allows digits plus `+ ( ) - space`, and requires
    /// 9–11 actual digits (NZ landlines are 9, mobiles/toll-free run up to 11).
    static func phoneError(_ phone: String, required: Bool = false) -> String? {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return required ? "Phone number is required" : nil }

        let allowed = CharacterSet(charactersIn: "0123456789 +()-")
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Phone number can only contain digits"
        }
        let digitCount = trimmed.filter { $0.isNumber }.count
        if digitCount < 9 || digitCount > 11 {
            return "Enter a valid phone number (9–11 digits)"
        }
        return nil
    }

    // MARK: - Password

    /// Minimum 8 characters with an uppercase letter, a lowercase letter, a number,
    /// and a special character. Keep this message and the rule in sync.
    static let passwordRequirementMessage =
        "Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number, and a special character."

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
            && password.range(of: "[A-Z]", options: .regularExpression) != nil
            && password.range(of: "[a-z]", options: .regularExpression) != nil
            && password.range(of: "[0-9]", options: .regularExpression) != nil
            && password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }

    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return "Password is required" }
        if !isValidPassword(password) { return passwordRequirementMessage }
        return nil
    }

    // MARK: - Date of Birth

    /// Rejects future dates and, when `minimumAge` is supplied, ages below it.
    static func dateOfBirthError(_ date: Date, minimumAge: Int? = nil) -> String? {
        let calendar = Calendar.current
        let today = Date()
        if calendar.startOfDay(for: date) > calendar.startOfDay(for: today) {
            return "Date of Birth cannot be in the future"
        }
        if let minimumAge,
           let age = calendar.dateComponents([.year], from: date, to: today).year,
           age < minimumAge {
            return "You must be at least \(minimumAge) years old to register"
        }
        return nil
    }
}
