import Foundation

enum DynamicJSON {
    static func object(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    static func values(in object: Any, path: String) -> [Any] {
        let parts = path.split(separator: ".").map(String.init)
        return values(in: object, parts: parts)
    }

    static func firstString(in object: Any, paths: [String]) -> String? {
        for path in paths {
            for value in values(in: object, path: path) {
                if let string = value as? String, !string.isEmpty {
                    return string
                }
                if let number = value as? NSNumber {
                    return number.stringValue
                }
            }
        }
        return nil
    }

    static func numericValues(in object: Any, path: String) -> [Double] {
        values(in: object, path: path).compactMap { value in
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String {
                return Double(string)
            }
            return nil
        }
    }

    private static func values(in object: Any, parts: [String]) -> [Any] {
        guard let head = parts.first else {
            return [object]
        }

        let tail = Array(parts.dropFirst())
        if head == "*" {
            if let array = object as? [Any] {
                return array.flatMap { values(in: $0, parts: tail) }
            }
            if let dict = object as? [String: Any] {
                return dict.values.flatMap { values(in: $0, parts: tail) }
            }
            return []
        }

        if let dict = object as? [String: Any], let next = dict[head] {
            return values(in: next, parts: tail)
        }

        if let array = object as? [Any], let index = Int(head), array.indices.contains(index) {
            return values(in: array[index], parts: tail)
        }

        return []
    }
}
