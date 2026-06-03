import SwiftUI

/// Parent/child toggles for Settings → Capture → Content Types.
struct CaptureContentTypeSettings: View {
    @Binding var enabledGroups: Set<CaptureContentGroup>
    @Binding var capturedTypes: Set<ClipboardContentType>

    var body: some View {
        ForEach(CaptureContentGroup.allCases) { group in
            Section {
                Toggle(isOn: parentBinding(for: group)) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.displayName)
                            Text(group.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: group.systemImage)
                    }
                }

                if group.contentTypes.count > 1 {
                    if enabledGroups.contains(group) {
                        ForEach(group.contentTypes) { type in
                            Toggle(isOn: childBinding(type: type, group: group)) {
                                Label(type.displayName, systemImage: type.systemImage)
                            }
                            .padding(.leading, 8)
                        }
                    } else {
                        ForEach(group.contentTypes) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
    }

    private func parentBinding(for group: CaptureContentGroup) -> Binding<Bool> {
        Binding(
            get: { enabledGroups.contains(group) },
            set: { on in
                if on {
                    enabledGroups.insert(group)
                    let children = Set(group.contentTypes)
                    if group.contentTypes.count == 1 {
                        capturedTypes.formUnion(children)
                    } else if children.isDisjoint(with: capturedTypes) {
                        capturedTypes.formUnion(children)
                    }
                } else {
                    enabledGroups.remove(group)
                    if group.contentTypes.count == 1, let only = group.contentTypes.first {
                        capturedTypes.remove(only)
                    }
                }
                persist()
            }
        )
    }

    private func childBinding(type: ClipboardContentType, group: CaptureContentGroup) -> Binding<Bool> {
        Binding(
            get: { enabledGroups.contains(group) && capturedTypes.contains(type) },
            set: { on in
                guard enabledGroups.contains(group) else { return }
                if on {
                    capturedTypes.insert(type)
                } else {
                    capturedTypes.remove(type)
                }
                persist()
            }
        )
    }

    private func persist() {
        Preferences.enabledCaptureGroups = enabledGroups
        Preferences.capturedTypes = capturedTypes
    }
}
