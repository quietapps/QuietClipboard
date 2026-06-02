import Foundation

enum DateFormatting {
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relativeString(from date: Date, to ref: Date = .now) -> String {
        relative.localizedString(for: date, relativeTo: ref)
    }
}
