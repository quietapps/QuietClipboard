import Foundation
import NaturalLanguage
import SwiftData

@MainActor
enum CategorySuggestionService {
    /// Attach all suggestions at or above `threshold` to `item`, creating missing
    /// categories. Returns suggestions below the threshold for banner display.
    static func autoApply(
        suggestions: [CategorySuggestion],
        to item: ClipboardItem,
        context: ModelContext,
        threshold: Double
    ) -> [CategorySuggestion] {
        guard !suggestions.isEmpty else { return [] }
        let toApply  = suggestions.filter { $0.confidence >= threshold }
        let remaining = suggestions.filter { $0.confidence <  threshold }
        guard !toApply.isEmpty else { return remaining }

        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)])
        var existing = (try? context.fetch(descriptor)) ?? []

        for s in toApply {
            let cat: Category
            if let e = existing.first(where: { $0.name.caseInsensitiveCompare(s.name) == .orderedSame }) {
                cat = e
            } else {
                let nextOrder = (existing.last?.sortOrder ?? 0) + 1
                cat = Category(name: s.name, icon: s.icon, color: s.color, sortOrder: nextOrder)
                context.insert(cat)
                existing.append(cat)
            }
            if !item.categories.contains(where: { $0.id == cat.id }) {
                item.categories.append(cat)
            }
        }
        return remaining
    }

    static func suggest(for item: ClipboardItem, useML: Bool? = nil) -> [CategorySuggestion] {
        let useML = useML ?? Preferences.autoCategorizationML
        var results: [CategorySuggestion] = []
        let text = combinedText(for: item)

        if item.isSensitive || SensitiveDetector.isSensitive(text, isConcealed: false) {
            results.append(CategorySuggestion(
                name: "Secrets & Keys",
                icon: "key.fill",
                color: "#FF453A",
                confidence: 0.95,
                reason: "Sensitive patterns detected"
            ))
        }

        if matchesAPIKey(text) {
            results.append(CategorySuggestion(
                name: "API Keys",
                icon: "key.horizontal.fill",
                color: "#FF9F0A",
                confidence: 0.92,
                reason: "API key or token patterns"
            ))
        }

        if item.contentType == .color || ColorParsing.isColorString(text) {
            results.append(CategorySuggestion(
                name: "Design Colors",
                icon: "paintpalette.fill",
                color: "#BF5AF2",
                confidence: 0.9,
                reason: "Color value detected"
            ))
        }

        if item.contentType == .code || ContentTypeDetector.looksLikeCode(text) {
            let lang = CodeHighlighter.detectLanguage(text).displayName
            results.append(CategorySuggestion(
                name: "Code (\(lang))",
                icon: "chevron.left.forwardslash.chevron.right",
                color: "#64D2FF",
                confidence: 0.88,
                reason: "Code structure detected"
            ))
        }

        if item.contentType == .markdown {
            results.append(CategorySuggestion(
                name: "Markdown",
                icon: "text.document",
                color: "#5AC8FA",
                confidence: 0.86,
                reason: "Markdown document"
            ))
        }

        if item.contentType == .link {
            results.append(CategorySuggestion(
                name: "Links & References",
                icon: "link",
                color: "#30D158",
                confidence: 0.85,
                reason: "URL clipboard content"
            ))
        }

        if looksLikeMeetingNotes(text) {
            results.append(CategorySuggestion(
                name: "Meeting Notes",
                icon: "person.3.fill",
                color: "#5E5CE6",
                confidence: 0.82,
                reason: "Meeting-related keywords"
            ))
        }

        if looksLikeEmailDraft(text) {
            results.append(CategorySuggestion(
                name: "Email Drafts",
                icon: "envelope.fill",
                color: "#FFD60A",
                confidence: 0.8,
                reason: "Email-style content"
            ))
        }

        if item.contentType == .image || item.contentType == .screenshot {
            results.append(CategorySuggestion(
                name: "Screenshots",
                icon: "camera.viewfinder",
                color: "#AC8E68",
                confidence: 0.78,
                reason: "Image capture"
            ))
        }

        if useML, let ml = mlTopicLabel(for: text) {
            results.append(CategorySuggestion(
                name: ml.name,
                icon: ml.icon,
                color: ml.color,
                confidence: ml.confidence,
                reason: "On-device language analysis"
            ))
        }

        return dedupe(results).sorted { $0.confidence > $1.confidence }.prefix(4).map { $0 }
    }

    private static func combinedText(for item: ClipboardItem) -> String {
        [item.textContent, item.ocrText, item.title, item.linkPreviewTitle]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private static func matchesAPIKey(_ text: String) -> Bool {
        let patterns = ["sk-", "pk_", "api_key=", "AKIA", "ghp_", "github_pat_", "Bearer ", "xoxb-", "xoxp-"]
        return patterns.contains { text.contains($0) }
    }

    private static func looksLikeMeetingNotes(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keys = ["agenda", "attendees", "action items", "meeting notes", "standup", "retro", "zoom", "teams meeting"]
        let hits = keys.filter { lower.contains($0) }.count
        return hits >= 2 || (hits >= 1 && lower.contains(":"))
    }

    private static func looksLikeEmailDraft(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("subject:") || lower.contains("dear ") || lower.contains("best regards")
    }

    private static func mlTopicLabel(for text: String) -> (name: String, icon: String, color: String, confidence: Double)? {
        guard text.count >= 40 else { return nil }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = String(text.prefix(4000))
        var nouns: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun {
                nouns.append(String(text[range]).lowercased())
            }
            return true
        }
        let joined = nouns.joined(separator: " ")
        if joined.contains("invoice") || joined.contains("payment") {
            return ("Finance", "dollarsign.circle.fill", "#30D158", 0.72)
        }
        if joined.contains("design") || joined.contains("mockup") || joined.contains("figma") {
            return ("Design", "paintbrush.fill", "#BF5AF2", 0.7)
        }
        if joined.contains("bug") || joined.contains("error") || joined.contains("stack") {
            return ("Debugging", "ladybug.fill", "#FF453A", 0.68)
        }
        return nil
    }

    private static func dedupe(_ list: [CategorySuggestion]) -> [CategorySuggestion] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.name).inserted }
    }
}
