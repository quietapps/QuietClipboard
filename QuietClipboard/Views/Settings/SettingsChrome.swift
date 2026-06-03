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

    /// Shorter label for the top tab bar.
    var tabTitle: String {
        switch self {
        case .quickSearch: return "Search"
        case .shortcuts: return "Keys"
        case .statistics: return "Stats"
        default: return title
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

// MARK: - Chrome tokens

enum SettingsChrome {
    /// Matches `LibraryWindow` (.background(.black)).
    static let shellBackground = Color.black
    /// Inclusive tab + content panel (Library detail panel uses ~0.08 gray on black).
    static let panelSurface = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let contentBackground = panelSurface
    static let groupedBackground = Color.white.opacity(0.06)
    static let groupedStroke = Color.white.opacity(0.08)
    static let panelStroke = Color.white.opacity(0.08)
    static let tabSelectedFill = Color.white.opacity(0.12)
    static let footerBackground = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let divider = Color.white.opacity(0.08)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.38)
    static let sectionHeaderText = Color.white.opacity(0.42)
    static let controlFill = Color.white.opacity(0.1)
    static let accent = Color(red: 0.35, green: 0.58, blue: 1.0)

    static let rowHorizontalPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 10
    static let rowIconSize: CGFloat = 28
    static let rowIconCorner: CGFloat = 7
    static let nestedRowIndent: CGFloat = 44
    static let rowColumnSpacing: CGFloat = 12
    static let controlColumnWidth: CGFloat = 52
    static let controlColumnWidthWide: CGFloat = 200
    static let groupedCornerRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 20
    static let dividerLeadingInset: CGFloat = rowHorizontalPadding + rowIconSize + rowColumnSpacing

    /// Fits all seven top tabs in one row without scrolling.
    static let windowWidth: CGFloat = 540
    /// Tall enough for General tab (three sections) without a scrollbar on first open.
    static let windowMinHeight: CGFloat = 620
    static let windowIdealHeight: CGFloat = 620
    static let tabSpacing: CGFloat = 2
    static let tabBarHorizontalPadding: CGFloat = 6
    static let tabBarVerticalPadding: CGFloat = 9
    static let tabIconSize: CGFloat = 16
    static let tabLabelSize: CGFloat = 11
    static let tabLabelSpacing: CGFloat = 4
    static let tabPillHorizontalPadding: CGFloat = 7
    static let tabPillVerticalPadding: CGFloat = 6
    static let tabPillCornerRadius: CGFloat = 7
    static let shellTopInset: CGFloat = 14
    static let shellBottomInset: CGFloat = 12
    static let shellHorizontalInset: CGFloat = 12
    static let shellSectionSpacing: CGFloat = 10
    static let panelCornerRadius: CGFloat = 12
    static let footerCornerRadius: CGFloat = 10
}

enum SettingsIconTint {
    case purple, blue, green, orange, red, pink, teal, indigo, gray

    var background: Color {
        switch self {
        case .purple: return Color(red: 0.45, green: 0.32, blue: 0.72)
        case .blue: return Color(red: 0.28, green: 0.45, blue: 0.82)
        case .green: return Color(red: 0.28, green: 0.62, blue: 0.42)
        case .orange: return Color(red: 0.82, green: 0.48, blue: 0.22)
        case .red: return Color(red: 0.78, green: 0.28, blue: 0.32)
        case .pink: return Color(red: 0.82, green: 0.35, blue: 0.55)
        case .teal: return Color(red: 0.22, green: 0.62, blue: 0.62)
        case .indigo: return Color(red: 0.35, green: 0.38, blue: 0.78)
        case .gray: return Color.white.opacity(0.18)
        }
    }
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
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: SettingsChrome.shellTopInset)

            settingsPanel

            Spacer()
                .frame(height: SettingsChrome.shellSectionSpacing)

            SettingsFooterBar(
                isPaused: monitor.isPaused,
                onOpenLibrary: { coordinator.openLibraryWindow() },
                onQuit: { NSApp.terminate(nil) }
            )
            .padding(.horizontal, SettingsChrome.shellHorizontalInset)

            Spacer()
                .frame(height: SettingsChrome.shellBottomInset)
        }
        .background(SettingsChrome.shellBackground)
        .environment(\.settingsDarkChrome, true)
    }

    /// Tabs + content share one rounded surface (Quiet Reminder–style).
    private var settingsPanel: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $panel)

            SettingsChromeDivider()
                .padding(.horizontal, 10)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(SettingsChrome.panelSurface, in: panelShape)
        .overlay(panelShape.stroke(SettingsChrome.panelStroke, lineWidth: 1))
        .padding(.horizontal, SettingsChrome.shellHorizontalInset)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SettingsChrome.panelCornerRadius, style: .continuous)
    }

}

// MARK: - Top tab bar

struct SettingsTabBar: View {
    @Binding var selection: SettingsPanel

    var body: some View {
        HStack(alignment: .center, spacing: SettingsChrome.tabSpacing) {
            ForEach(SettingsPanel.allCases) { panel in
                tabButton(panel)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, SettingsChrome.tabBarHorizontalPadding)
        .padding(.vertical, SettingsChrome.tabBarVerticalPadding)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ panel: SettingsPanel) -> some View {
        let isActive = selection == panel
        let pillShape = RoundedRectangle(cornerRadius: SettingsChrome.tabPillCornerRadius, style: .continuous)
        return Button {
            selection = panel
        } label: {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: SettingsChrome.tabLabelSpacing) {
                    Image(systemName: panel.systemImage)
                        .font(.system(size: SettingsChrome.tabIconSize, weight: .medium))
                    Text(panel.tabTitle)
                        .font(.system(size: SettingsChrome.tabLabelSize, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(isActive ? SettingsChrome.accent : SettingsChrome.secondaryText)
                .padding(.horizontal, SettingsChrome.tabPillHorizontalPadding)
                .padding(.vertical, SettingsChrome.tabPillVerticalPadding)
                .background(pillShape.fill(isActive ? SettingsChrome.tabSelectedFill : Color.clear))
                .contentShape(pillShape)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsTabButtonStyle())
        .pointerCursor()
        .accessibilityLabel(panel.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Expands the clickable region to the full tab cell (not just icon/text glyphs).
private struct SettingsTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Footer

struct SettingsFooterBar: View {
    let isPaused: Bool
    let onOpenLibrary: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isPaused ? "pause.circle.fill" : "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPaused ? .orange : .green)
                Text(isPaused ? "Capture paused" : "Capture active")
                    .font(.caption)
                    .foregroundStyle(SettingsChrome.secondaryText)
            }

            Spacer()

            HStack(spacing: 0) {
                footerAction(title: "Library", systemImage: "books.vertical", action: onOpenLibrary)

                Rectangle()
                    .fill(SettingsChrome.divider)
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 10)

                footerAction(title: "Quit", systemImage: "power", action: onQuit)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(SettingsChrome.footerBackground, in: RoundedRectangle(cornerRadius: SettingsChrome.footerCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsChrome.footerCornerRadius, style: .continuous)
                .stroke(SettingsChrome.panelStroke, lineWidth: 1)
        )
    }

    private func footerAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.medium))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(SettingsChrome.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
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

// MARK: - Scroll + sections

struct SettingsScrollContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsChrome.sectionSpacing) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.automatic)
        .background(Color.clear)
    }
}

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SettingsChrome.sectionHeaderText)
            .tracking(0.5)
            .padding(.leading, 2)
    }
}

struct SettingsCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                SettingsSectionHeader(title: title)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(SettingsChrome.groupedBackground, in: RoundedRectangle(cornerRadius: SettingsChrome.groupedCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsChrome.groupedCornerRadius, style: .continuous)
                    .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
            )

            if let footer, !footer.isEmpty {
                SettingsFooterText(footer)
            }
        }
    }
}

/// Legacy header — maps to section style when used standalone.
struct SettingsCardHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        SettingsSectionHeader(title: title)
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
            .padding(.leading, 2)
    }
}

struct SettingsChromeDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsChrome.divider)
            .frame(height: 1)
    }
}

struct SettingsInsetDivider: View {
    var leadingInset: CGFloat = SettingsChrome.dividerLeadingInset

    var body: some View {
        Rectangle()
            .fill(SettingsChrome.divider)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Row icon

struct SettingsRowIcon: View {
    let systemImage: String
    var tint: SettingsIconTint = .gray

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: SettingsChrome.rowIconSize, height: SettingsChrome.rowIconSize)
            .background(tint.background, in: RoundedRectangle(cornerRadius: SettingsChrome.rowIconCorner, style: .continuous))
    }
}

// MARK: - Row layout

struct SettingsRowColumns<Label: View, Control: View>: View {
    var icon: String? = nil
    var iconTint: SettingsIconTint = .gray
    var indent: CGFloat = 0
    var controlWidth: CGFloat = SettingsChrome.controlColumnWidth
    var alignment: VerticalAlignment = .center
    @ViewBuilder var label: () -> Label
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: alignment, spacing: SettingsChrome.rowColumnSpacing) {
            if let icon {
                SettingsRowIcon(systemImage: icon, tint: iconTint)
            } else if indent > 0 {
                Color.clear
                    .frame(width: SettingsChrome.rowIconSize, height: SettingsChrome.rowIconSize)
            }

            label()
                .padding(.leading, indent > 0 && icon == nil ? indent - SettingsChrome.rowIconSize - SettingsChrome.rowColumnSpacing : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(width: controlWidth, alignment: .trailing)
        }
        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
    }
}

// MARK: - Rows

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconTint: SettingsIconTint = .blue
    var indent: CGFloat = 0
    @Binding var isOn: Bool
    var disabled: Bool = false

    private var hasSubtitle: Bool { subtitle != nil }
    private var showIcon: Bool { icon != nil && indent == 0 }

    var body: some View {
        SettingsRowColumns(
            icon: showIcon ? icon : nil,
            iconTint: iconTint,
            indent: indent,
            alignment: hasSubtitle ? .top : .center
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
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
                .tint(SettingsChrome.accent)
                .disabled(disabled)
        }
        .padding(.vertical, hasSubtitle ? 12 : SettingsChrome.rowVerticalPadding)
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
    var subtitle: String? = nil
    var icon: String? = nil
    var iconTint: SettingsIconTint = .blue
    var indent: CGFloat = 0
    var disabled: Bool = false
    @Binding var selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        SettingsRowColumns(
            icon: icon,
            iconTint: iconTint,
            indent: indent,
            controlWidth: SettingsChrome.controlColumnWidthWide,
            alignment: subtitle != nil ? .top : .center
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(disabled ? SettingsChrome.tertiaryText : SettingsChrome.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(SettingsChrome.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } control: {
            Picker("", selection: $selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(disabled)
        }
        .padding(.vertical, subtitle != nil ? 12 : SettingsChrome.rowVerticalPadding)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct SettingsLabeledFieldRow: View {
    let title: String
    var icon: String? = nil
    var iconTint: SettingsIconTint = .blue
    var indent: CGFloat = 0
    @ViewBuilder var field: () -> AnyView

    init<Content: View>(
        title: String,
        icon: String? = nil,
        iconTint: SettingsIconTint = .blue,
        indent: CGFloat = 0,
        @ViewBuilder field: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconTint = iconTint
        self.indent = indent
        self.field = { AnyView(field()) }
    }

    var body: some View {
        SettingsRowColumns(icon: icon, iconTint: iconTint, indent: indent, controlWidth: 88) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SettingsChrome.primaryText)
        } control: {
            field()
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}

struct SettingsValueRow<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var iconTint: SettingsIconTint = .blue
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        SettingsRowColumns(icon: icon, iconTint: iconTint, controlWidth: SettingsChrome.controlColumnWidthWide) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SettingsChrome.primaryText)
        } control: {
            trailing()
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}

// MARK: - Action buttons

enum SettingsButtonVariant {
    case secondary
    case primary
    case destructive
}

enum SettingsActionButtonSize {
    case regular
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

struct SettingsActionStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
        .padding(.vertical, 10)
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
        guard isEnabled else { return SettingsChrome.controlFill.opacity(0.6) }
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
        guard isEnabled else { return SettingsChrome.groupedStroke }
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
            .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
            .padding(.bottom, 10)
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
                    .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
            )
    }
}
