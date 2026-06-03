import Foundation

struct CategorySuggestion: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let icon: String
    let color: String
    let confidence: Double
    let reason: String
}

enum CategorySuggestionCodec {
    static func encode(_ suggestions: [CategorySuggestion]) -> String? {
        guard !suggestions.isEmpty else { return nil }
        let data = try? JSONEncoder().encode(suggestions)
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    static func decode(_ json: String?) -> [CategorySuggestion] {
        guard let json, let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([CategorySuggestion].self, from: data) else {
            return []
        }
        return list
    }
}
