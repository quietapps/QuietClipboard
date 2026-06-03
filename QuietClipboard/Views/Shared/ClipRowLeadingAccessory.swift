import SwiftUI

/// Leading thumbnail (rich) or type icon (compact) for clip rows and cards.
struct ClipRowLeadingAccessory: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem
    var richSize: CGSize = CGSize(width: 50, height: 50)

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var style: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        switch style {
        case .rich:
            ClipboardItemPreview(item: item)
                .frame(width: richSize.width, height: richSize.height)
        case .compact:
            Image(systemName: item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
                  ? "lock.fill" : item.contentType.systemImage)
                .font(.system(size: min(richSize.width, richSize.height) * 0.42))
                .foregroundStyle(.secondary)
                .frame(width: richSize.width, height: richSize.height)
        }
    }
}
