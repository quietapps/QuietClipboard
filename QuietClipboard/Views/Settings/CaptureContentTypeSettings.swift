import SwiftUI

/// Parent/child toggles for Settings → Capture → Content Types.
struct CaptureContentTypeSettings: View {
    @Binding var enabledGroups: Set<CaptureContentGroup>
    @Binding var capturedTypes: Set<ClipboardContentType>

    var body: some View {
        ForEach(Array(CaptureContentGroup.allCases.enumerated()), id: \.element.id) { index, group in
            groupBlock(group)
            if index < CaptureContentGroup.allCases.count - 1 {
                SettingsInsetDivider()
            }
        }
    }

    @ViewBuilder
    private func groupBlock(_ group: CaptureContentGroup) -> some View {
        SettingsToggleRow(
            title: group.displayName,
            subtitle: group.summary,
            isOn: parentBinding(for: group)
        )

        if group.contentTypes.count > 1 {
            if enabledGroups.contains(group) {
                ForEach(group.contentTypes) { type in
                    childToggle(type: type, group: group)
                }
            } else {
                ForEach(group.contentTypes) { type in
                    SettingsDisabledTypeRow(
                        title: type.displayName,
                        systemImage: type.systemImage
                    )
                }
            }
        }
    }

    private func childToggle(type: ClipboardContentType, group: CaptureContentGroup) -> some View {
        SettingsToggleRow(
            title: type.displayName,
            indent: SettingsChrome.nestedRowIndent,
            isOn: childBinding(type: type, group: group)
        )
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
