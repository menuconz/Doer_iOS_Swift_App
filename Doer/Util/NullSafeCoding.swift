import Foundation

// Override KeyedDecodingContainer to handle null JSON values for non-optional types.
// Swift's auto-synthesized Codable init calls these decode methods.
// By overriding them to use decodeIfPresent, null values get mapped to defaults.

extension KeyedDecodingContainer {

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        return (try? decodeIfPresent(type, forKey: key)) ?? ""
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        return (try? decodeIfPresent(type, forKey: key)) ?? 0
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        return (try? decodeIfPresent(type, forKey: key)) ?? 0
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        return (try? decodeIfPresent(type, forKey: key)) ?? 0.0
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        return (try? decodeIfPresent(type, forKey: key)) ?? false
    }

    func decode<T: Decodable>(_ type: [T].Type, forKey key: K) throws -> [T] {
        return (try? decodeIfPresent(type, forKey: key)) ?? []
    }
}
