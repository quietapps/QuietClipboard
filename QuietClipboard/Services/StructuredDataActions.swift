import AppKit
import Contacts
import EventKit
import Foundation

@MainActor
enum StructuredDataActions {
    static func copyNormalized(_ match: StructuredDataMatch) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(match.normalized, forType: .string)
    }

    static func createReminder(from match: StructuredDataMatch) {
        guard match.kind == .isoDate, let due = match.parsedDate else { return }
        let store = EKEventStore()
        store.requestFullAccessToReminders { granted, error in
            Task { @MainActor in
                guard granted, error == nil else {
                    showAlert("Reminders access is required to create a reminder.")
                    return
                }
                guard let calendar = store.defaultCalendarForNewReminders() else {
                    showAlert("No Reminders list available.")
                    return
                }
                let reminder = EKReminder(eventStore: store)
                reminder.title = "Clipboard: \(match.raw)"
                reminder.calendar = calendar
                reminder.notes = "Created from Quiet Clipboard"
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: due
                )
                reminder.dueDateComponents = comps
                do {
                    try store.save(reminder, commit: true)
                    showAlert("Reminder created.", style: .informational)
                } catch {
                    showAlert("Could not save reminder: \(error.localizedDescription)")
                }
            }
        }
    }

    static func createContact(from match: StructuredDataMatch) {
        guard match.kind.supportsContact else { return }
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            Task { @MainActor in
                guard granted, error == nil else {
                    showAlert("Contacts access is required to add a contact.")
                    return
                }
                let contact = CNMutableContact()
                switch match.kind {
                case .email:
                    contact.emailAddresses = [
                        CNLabeledValue(label: CNLabelHome, value: match.normalized as NSString)
                    ]
                case .phone:
                    contact.phoneNumbers = [
                        CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: match.normalized))
                    ]
                default:
                    return
                }
                let save = CNSaveRequest()
                save.add(contact, toContainerWithIdentifier: nil)
                do {
                    try store.execute(save)
                    showAlert("Contact added.", style: .informational)
                } catch {
                    showAlert("Could not save contact: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func showAlert(_ message: String, style: NSAlert.Style = .warning) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
