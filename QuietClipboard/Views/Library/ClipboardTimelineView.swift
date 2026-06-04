import SwiftUI
import SwiftData

struct ClipboardTimelineView: View {
    let items: [ClipboardItem]
    @ObservedObject var libraryState: LibraryState
    @Binding var selectedID: UUID?
    var onActivate: (ClipboardItem) -> Void
    var onItemTap: (ClipboardItem) -> Void

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 0) {
            dayPicker
            Divider()
            ScrollView {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No clips this day",
                        systemImage: "calendar",
                        description: Text("Try another date or copy something new.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(sections) { section in
                            timelineSection(section)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var dayPicker: some View {
        HStack {
            Button {
                selectedDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button {
                let next = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                if next <= calendar.startOfDay(for: .now) {
                    selectedDay = next
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(calendar.isDate(selectedDay, inSameDayAs: .now))

            Button("Today") {
                selectedDay = calendar.startOfDay(for: .now)
            }
            .buttonStyle(.link)
        }
        .padding(10)
    }

    private var sections: [TimelineSection] {
        TimelineBuilder.sections(for: items, day: selectedDay, calendar: calendar)
    }

    @ViewBuilder
    private func timelineSection(_ section: TimelineSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.hourLabel)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(section.totalEntries) clips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(section.appGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Label(group.appName, systemImage: "app.dashed")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(group.entries) { entry in
                        timelineRow(entry)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        let item = entry.item
        let queued = libraryState.isQueued(item.id)
        let position = libraryState.queuePosition(for: item.id, in: items)

        return Button {
            onItemTap(item)
        } label: {
            HStack(spacing: 10) {
                ClipRowLeadingAccessory(item: entry.item, richSize: CGSize(width: 44, height: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.item.title ?? entry.item.textContent ?? "Untitled")
                        .lineLimit(1)
                        .font(.callout)
                    HStack(spacing: 4) {
                        Image(systemName: entry.item.contentType.systemImage)
                        Text(entry.item.contentType.displayName)
                        Text("·")
                        Text(entry.copiedAt.formatted(date: .omitted, time: .shortened))
                        if entry.isRepeatCopy {
                            Text("· repeat")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.item.effectiveCopyCount > 1 {
                    Text("×\(entry.item.effectiveCopyCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(timelineRowBackground(selected: selectedID == item.id, queued: queued))
            )
            .overlay(alignment: .leading) {
                if queued, let position {
                    Text("\(position)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(red: 0.2, green: 0.72, blue: 0.45), in: Circle())
                        .offset(x: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onActivate(item) })
        .pointerCursor()
    }

    private func timelineRowBackground(selected: Bool, queued: Bool) -> Color {
        if selected { return Color.accentColor.opacity(0.15) }
        if queued { return Color(red: 0.2, green: 0.72, blue: 0.45).opacity(0.12) }
        return Color(nsColor: .controlBackgroundColor)
    }
}

// MARK: - Timeline model

struct TimelineEntry: Identifiable {
    let id: UUID
    let item: ClipboardItem
    let copiedAt: Date
    let appName: String
    let isRepeatCopy: Bool
}

struct TimelineAppGroup: Identifiable {
    let id: String
    let appName: String
    let entries: [TimelineEntry]
}

struct TimelineSection: Identifiable {
    let id: Int
    let hour: Int
    let hourLabel: String
    let appGroups: [TimelineAppGroup]

    var totalEntries: Int {
        appGroups.reduce(0) { $0 + $1.entries.count }
    }
}

enum TimelineBuilder {
    static func sections(
        for items: [ClipboardItem],
        day: Date,
        calendar: Calendar = .current
    ) -> [TimelineSection] {
        var entries: [TimelineEntry] = []

        for item in items {
            let events = item.sortedCopyEvents().filter { calendar.isDate($0.copiedAt, inSameDayAs: day) }
            if events.isEmpty {
                let stamp = item.effectiveLastCopiedAt
                guard calendar.isDate(stamp, inSameDayAs: day) else { continue }
                entries.append(TimelineEntry(
                    id: UUID(),
                    item: item,
                    copiedAt: stamp,
                    appName: item.sourceAppName ?? "Unknown",
                    isRepeatCopy: item.effectiveCopyCount > 1
                ))
            } else {
                for (idx, event) in events.enumerated() {
                    entries.append(TimelineEntry(
                        id: event.id,
                        item: item,
                        copiedAt: event.copiedAt,
                        appName: event.sourceAppName ?? item.sourceAppName ?? "Unknown",
                        isRepeatCopy: idx > 0 || item.effectiveCopyCount > 1
                    ))
                }
            }
        }

        entries.sort { $0.copiedAt > $1.copiedAt }

        let grouped = Dictionary(grouping: entries) { entry in
            calendar.component(.hour, from: entry.copiedAt)
        }

        return grouped.keys.sorted(by: >).map { hour in
            let hourEntries = grouped[hour] ?? []
            let byApp = Dictionary(grouping: hourEntries) { $0.appName }
            let appGroups = byApp.keys.sorted().map { app in
                TimelineAppGroup(
                    id: "\(hour)-\(app)",
                    appName: app,
                    entries: (byApp[app] ?? []).sorted { $0.copiedAt > $1.copiedAt }
                )
            }
            let label = hourLabel(hour: hour)
            return TimelineSection(id: hour, hour: hour, hourLabel: label, appGroups: appGroups)
        }
    }

    private static func hourLabel(hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
