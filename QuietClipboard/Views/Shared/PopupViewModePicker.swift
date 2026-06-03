import SwiftUI

struct PopupViewModePicker: View {
    @Binding var mode: PopupViewMode

    var body: some View {
        Picker("View", selection: $mode) {
            ForEach(PopupViewMode.allCases) { m in
                Image(systemName: m.systemImage).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 72)
        .help("List or grid view")
    }
}
