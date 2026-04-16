import Foundation

struct Constants {
    static let deviceTypeIOS = 1
    static let siteId = 1
    static let lId = 1

    /// Returns current NZ time formatted as ISO datetime string (matches server's DateTimeService)
    static func nowNz() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Pacific/Auckland")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
