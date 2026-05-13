import Foundation

enum FairShareFormatters {
    static func currency(_ amount: Double, code: String = "INR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(code) \(amount)"
    }

    static func day(_ isoString: String) -> String {
        let prefix = String(isoString.prefix(10))
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return prefix }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

