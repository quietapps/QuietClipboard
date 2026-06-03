import Foundation

enum StructuredDataKind: String, Codable, CaseIterable, Identifiable {
    case email
    case phone
    case uuid
    case isoDate
    case iban
    case ipAddress
    case semver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        case .uuid: return "UUID"
        case .isoDate: return "Date"
        case .iban: return "IBAN"
        case .ipAddress: return "IP"
        case .semver: return "Version"
        }
    }

    var systemImage: String {
        switch self {
        case .email: return "envelope"
        case .phone: return "phone"
        case .uuid: return "number"
        case .isoDate: return "calendar"
        case .iban: return "building.columns"
        case .ipAddress: return "network"
        case .semver: return "tag"
        }
    }

    var supportsReminder: Bool { self == .isoDate }
    var supportsContact: Bool { self == .email || self == .phone }
}

struct StructuredDataMatch: Codable, Equatable, Identifiable {
    var id: String { "\(kind.rawValue):\(normalized)" }
    let kind: StructuredDataKind
    let raw: String
    let normalized: String

    var parsedDate: Date? {
        guard kind == .isoDate else { return nil }
        return StructuredDataDetector.parseISODate(normalized)
    }
}
