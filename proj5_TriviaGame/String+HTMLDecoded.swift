//
//  String+HTMLDecoded.swift
//  proj5_TriviaGame
//
//  Created by Andy Espinoza on 3/12/26.
//

import Foundation

extension String {
    var htmlDecoded: String {
        var s = self

        // Common named entities used by OpenTDB
        let named: [String: String] = [
            "&quot;": "\"",
            "&#039;": "'",
            "&apos;": "'",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " "
        ]
        for (k, v) in named {
            s = s.replacingOccurrences(of: k, with: v)
        }

        // Decode numeric entities like &#8217; and hex entities like &#x27;
        s = s.decodingNumericHTMLEntities()

        return s
    }

    private func decodingNumericHTMLEntities() -> String {
        var result = self

        // Decimal: &#1234;
        result = result.replacingOccurrences(
            of: #"&#(\d+);"#,
            with: { match in
                let numStr = match[1]
                if let value = Int(numStr), let scalar = UnicodeScalar(value) {
                    return String(Character(scalar))
                }
                return match[0]
            }
        )

        // Hex: &#x1F600;
        result = result.replacingOccurrences(
            of: #"&#x([0-9A-Fa-f]+);"#,
            with: { match in
                let hexStr = match[1]
                if let value = Int(hexStr, radix: 16), let scalar = UnicodeScalar(value) {
                    return String(Character(scalar))
                }
                return match[0]
            }
        )

        return result
    }
}

// MARK: - Small regex helper
private extension String {
    func replacingOccurrences(of pattern: String, with transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let ns = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: ns.length))

        var output = self
        for m in matches.reversed() {
            var groups: [String] = []
            groups.append(ns.substring(with: m.range)) // whole match at [0]
            for i in 1..<m.numberOfRanges {
                let r = m.range(at: i)
                groups.append(r.location != NSNotFound ? ns.substring(with: r) : "")
            }
            let replacement = transform(groups)
            output = (output as NSString).replacingCharacters(in: m.range, with: replacement)
        }
        return output
    }
}
