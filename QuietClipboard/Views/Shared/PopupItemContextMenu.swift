import SwiftUI

struct PopupItemContextMenu: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem

    var body: some View {
        if PasteSimulator.plainText(from: item) != nil {
            Button {
                coordinator.typeItem(item)
            } label: {
                Label("Type into App", systemImage: "keyboard")
            }
        }
        TextTransformMenu(item: item)
    }
}
