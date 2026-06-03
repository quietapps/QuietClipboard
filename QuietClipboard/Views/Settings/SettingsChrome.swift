import SwiftUI
import AppKit

// MARK: - Panel

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general
    case quickSearch
    case capture
    case shortcuts
    case statistics
    case storage
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .quickSearch: return "Quick Search"
        case .capture: return "Capture"
        case .shortcuts: return "Shortcuts"
        case .statistics: return "Statistics"
        case .storage: return "Storage"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .quickSearch: return "magnifyingglass"
        case .capture: return "doc.on.clipboard"
        case .shortcuts: return "command"
        case .statistics: return "chart.bar.xaxis"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Chrome tokens (matches Library window + detail panel)

enum SettingsChrome {
    static let shellBackground = Color.black
    static let panelBackground = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let cardBackground = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.08)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.38)
    static let pillInactive = Color.white.opacity(0.12)
    static let controlFill = Color.white.opacity(0.1)

    static let sidebarWidth: CGFloat = 172
    static let rowVerticalPadding: CGFloat = 5
    static let nestedRowIndent: CGFloat = 16
    static let rowColumnSpacing: CGFloat = 12
    /// Trailing column — toggles, pickers, fields align here.
    static let controlColumnWidth: CGFloat = 52
    static let controlColumnWidthWide: CGFloat = 200
}

private struct SettingsDarkChromeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var settingsDarkChrome: Bool {
        get { self[SettingsDarkChromeKey.self] }
        set { self[SettingsDarkChromeKey.self] = newValue }
    }
}

// MARK: - Shell

struct SettingsShell<Content: View>: View {
    @Binding var panel: SettingsPanel
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsTopBar()
            SettingsChromeDivider()
            HStack(alignment: .top, spacing: 0) {
                SettingsSidebar(selection: $panel)
                    .frame(width: SettingsChrome.sidebarWidth)
                Rectangle()
                    .fill(SettingsChrome.divider)
                    .frame(width: 1)
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(SettingsChrome.shellBackground)
        .environment(\.settingsDarkChrome, true)
    }
}

// MARK: - App icon

struct AppBrandIcon: View {
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 8

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel("Quiet Clipboard")
    }

    static var image: NSImage {
        if let icon = NSApp.applicationIconImage { return icon }
        if let named = NSImage(named: "AppIcon") { return named }
        return NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 1, height: 1))
    }
}

// MARK: - Top bar

struct SettingsTopBar: View {
    var body: some View {
        HStack(spacing: 12) {
            AppBrandIcon(size: 36, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quiet Clipboard")
                    .font(.headline)
                    .foregroundStyle(SettingsChrome.primaryText)
                Text("Settings")
                    .font(.subheadline)
                    .foregroundStyle(SettingsChrome.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Sidebar (section list)

struct SettingsSidebar: View {
    @Binding var selection: SettingsPanel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsPanel.allCases) { panel in
                    sidebarRow(panel)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(SettingsChrome.panelBackground)
    }

    private func sidebarRow(_ panel: SettingsPanel) -> some View {
        let isActive = selection == panel
        return Button {
            selection = panel
        } label: {
            HStack(spacing: 8) {
                Image(systemName: panel.systemImage)
                    .font(.subheadline)
                    .frame(width: 18)
                Text(panel.title)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? SettingsChrome.primaryText : SettingsChrome.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? SettingsChrome.pillInactive : Color.clear)
            )
        }
        .buttonStyle(.borderless)
        .pointerCursor()
    }
}

// MARK: - Scroll + cards

struct SettingsScrollContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SettingsChrome.shellBackground)
    }
}

struct SettingsCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                SettingsCardHeader(title: title, systemImage: systemImage)
            }
            content()
            if let footer, !footer.isEmpty {
                SettingsFooterText(footer)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsChrome.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SettingsChrome.cardStroke, lineWidth: 1)
        )
    }
}

struct SettingsCardHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SettingsChrome.secondaryText)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SettingsChrome.primaryText)
        }
    }
}

struct SettingsFooterText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsChromeDivider: View {
    var body: some View {
        Divider()
            .overlay(SettingsChrome.divider)
    }
}

struct SettingsInsetDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(SettingsChrome.divider)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Two-column row layout (label zone | control zone)

struct SettingsRowColumns<Label: View, Control: View>: View {
    var indent: CGFloat = 0
    var controlWidth: CGFloat = SettingsChrome.controlColumnWidth
    var alignment: VerticalAlignment = .center
    @ViewBuilder var label: () -> Label
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: alignment, spacing: SettingsChrome.rowColumnSpacing) {
            label()
                .padding(.leading, indent)
                .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(width: controlWidth, alignment: .trailing)
        }
    }
}

// MARK: - Rows

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var indent: CGFloat = 0
    @Binding var isOn: Bool
    var disabled: Bool = false

    private var hasSubtitle: Bool { subtitle != nil }

    var body: some View {
        SettingsRowColumns(indent: indent, alignment: hasSubtitle ? .top : .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(disabled ? SettingsChrome.tertiaryText : SettingsChrome.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(SettingsChrome.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } control: {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.white)
                .disabled(disabled)
        }
        .padding(.vertical, hasSubtitle ? 8 : SettingsChrome.rowVerticalPadding)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct SettingsDisabledTypeRow: View {
    let title: String
    var systemImage: String? = nil
    var indent: CGFloat = SettingsChrome.nestedRowIndent

    var body: some View {
        SettingsRowColumns(indent: indent) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .frame(width: 14)
                }
                Text(title)
                    .font(.subheadline)
            }
            .foregroundStyle(SettingsChrome.tertiaryText)
        } control: {
            Color.clear.frame(height: 1)
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}

struct SettingsPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    var indent: CGFloat = 0
    var disabled: Bool = false
    @Binding var selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        SettingsRowColumns(
            indent: indent,
            controlWidth: SettingsChrome.controlColumnWidthWide
        ) {
            Text(title)
                .font(.body)
                .foregroundStyle(disabled ? SettingsChrome.tertiaryText : SettingsChrome.primaryText)
        } control: {
            Picker("", selection: $selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(disabled)
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct SettingsLabeledFieldRow: View {
    let title: String
    var indent: CGFloat = 0
    @ViewBuilder var field: () -> AnyView

    init<Content: View>(title: String, indent: CGFloat = 0, @ViewBuilder field: @escaping () -> Content) {
        self.title = title
        self.indent = indent
        self.field = { AnyView(field()) }
    }

    var body: some View {
        SettingsRowColumns(indent: indent, controlWidth: 88) {
            Text(title)
                .font(.body)
                .foregroundStyle(SettingsChrome.primaryText)
        } control: {
            field()
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}

struct SettingsValueRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        SettingsRowColumns(controlWidth: SettingsChrome.controlColumnWidthWide) {
            Text(title)
                .font(.body)
                .foregroundStyle(SettingsChrome.primaryText)
        } control: {
            trailing()
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}

// MARK: - Action buttons

enum SettingsButtonVariant {
    /// Neutral actions (export, import, reset).
    case secondary
    /// Primary action in a card (clean up).
    case primary
    /// Destructive actions (clear, erase).
    case destructive
}

enum SettingsActionButtonSize {
    /// Full-width card actions (storage, danger zone).
    case regular
    /// Inline toolbars; matches compact settings chips (~36pt tall).
    case compact
}

struct SettingsActionButton: View {
    let title: String
    var systemImage: String? = nil
    var variant: SettingsButtonVariant = .secondary
    var size: SettingsActionButtonSize = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: size == .compact ? 6 : 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .imageScale(.medium)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(size == .compact ? 1 : 2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: size == .compact ? 36 : nil)
            .padding(.horizontal, size == .compact ? 12 : 16)
            .padding(.vertical, size == .compact ? 8 : 12)
        }
        .buttonStyle(SettingsFilledButtonStyle(variant: variant, cornerRadius: size == .compact ? 8 : 10))
        .pointerCursor()
    }
}

/// Vertical stack of full-width action buttons with consistent spacing.
struct SettingsActionStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
    }
}

private struct SettingsFilledButtonStyle: ButtonStyle {
    let variant: SettingsButtonVariant
    var cornerRadius: CGFloat = 10
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed), in: buttonShape)
            .overlay(buttonShape.stroke(borderColor, lineWidth: borderWidth))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .secondary, .destructive: return 1
        case .primary: return 0
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return SettingsChrome.tertiaryText }
        switch variant {
        case .secondary: return SettingsChrome.primaryText
        case .primary: return .black
        case .destructive: return Color(red: 1, green: 0.78, blue: 0.78)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            switch variant {
            case .primary: return SettingsChrome.controlFill
            default: return SettingsChrome.controlFill.opacity(0.6)
            }
        }
        switch variant {
        case .secondary:
            return Color.white.opacity(isPressed ? 0.14 : 0.1)
        case .primary:
            return Color.white.opacity(isPressed ? 0.9 : 1)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.28 : 0.22)
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return SettingsChrome.cardStroke }
        switch variant {
        case .secondary: return Color.white.opacity(0.14)
        case .primary: return Color.clear
        case .destructive: return Color.red.opacity(0.45)
        }
    }
}

struct SettingsCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsChrome.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsMonospaceField: View {
    @Binding var text: String
    var width: CGFloat = 72

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.body.monospacedDigit())
            .multilineTextAlignment(.trailing)
            .foregroundStyle(SettingsChrome.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: width)
            .background(SettingsChrome.controlFill, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SettingsChrome.cardStroke, lineWidth: 1)
            )
    }
}
