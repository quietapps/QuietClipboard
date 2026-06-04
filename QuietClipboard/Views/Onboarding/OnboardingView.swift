import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var initialStep: OnboardingStep? = nil
    var onComplete: () -> Void
    var onOpenCaptureSettings: () -> Void
    var onTryQuickSearch: () -> Void
    var onOpenLibrary: () -> Void

    @State private var stepIndex = 0
    @State private var didApplyInitialStep = false
    @State private var accessibilityGranted = AccessibilityPermissionHelper.isGranted

    private var step: OnboardingStep {
        OnboardingStep(rawValue: stepIndex) ?? .welcome
    }

    private var isLastStep: Bool { stepIndex >= OnboardingStep.allCases.count - 1 }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.top, 28)
                    .padding(.horizontal, 32)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 620)
        .onAppear {
            refreshAccessibility()
            if !didApplyInitialStep, let s = initialStep {
                stepIndex = s.rawValue
            }
            didApplyInitialStep = true
        }
        .onChange(of: stepIndex) { _, _ in refreshAccessibility() }
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            SettingsChrome.shellBackground
            RadialGradient(
                colors: [step.iconTint.opacity(0.22), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(step.iconTint.opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 2)
                Circle()
                    .stroke(step.iconTint.opacity(0.35), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: step.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(step.iconTint)
                    .symbolRenderingMode(.hierarchical)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: stepIndex)

            VStack(spacing: 8) {
                Text(step.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SettingsChrome.primaryText)
                    .multilineTextAlignment(.center)
                    .id("title-\(stepIndex)")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Text(step.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsChrome.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("subtitle-\(stepIndex)")
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: stepIndex)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .welcome:
                welcomeExtras
            case .capture:
                captureExtras
            case .privacy:
                privacyExtras
            case .accessibility:
                accessibilityExtras
            case .shortcuts:
                shortcutsExtras
            case .ready:
                readyExtras
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: stepIndex)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            progressDots

            HStack(spacing: 10) {
                if stepIndex > 0 {
                    Button("Back") { goBack() }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                }

                Spacer(minLength: 0)

                if !isLastStep {
                    Button("Skip tour") { finishEarly() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsChrome.tertiaryText)
                }

                Button(isLastStep ? "Get started" : "Continue") {
                    if isLastStep { onComplete() } else { goForward() }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases) { s in
                Capsule()
                    .fill(s.rawValue == stepIndex ? SettingsChrome.accent : Color.white.opacity(0.18))
                    .frame(width: s.rawValue == stepIndex ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: stepIndex)
            }
        }
    }

    // MARK: - Step bodies

    private var welcomeExtras: some View {
        VStack(spacing: 10) {
            featureRow(icon: "lock.fill", tint: .green, title: "Private & offline", detail: "Clips stay in ~/Library/Application Support/QuietClipboard/")
            featureRow(icon: "menubar.rectangle", tint: SettingsChrome.accent, title: "Lives in your menu bar", detail: "Recent history and pause controls one click away")
            featureRow(icon: "books.vertical.fill", tint: Color(red: 0.72, green: 0.55, blue: 1.0), title: "Full Library", detail: "Search, favorites, categories, and rich previews")
        }
        .padding(.top, 8)
    }

    private var captureExtras: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
            captureTypeChip("text.alignleft", "Text")
            captureTypeChip("link", "Links")
            captureTypeChip("photo", "Images")
            captureTypeChip("curlybraces", "Code")
            captureTypeChip("paintpalette.fill", "Colors")
            captureTypeChip("doc.fill", "Files")
        }
        .padding(.top, 4)
    }

    private var privacyExtras: some View {
        VStack(spacing: 14) {
            OnboardingGroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Already excluded")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SettingsChrome.sectionHeaderText)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        ForEach(ExcludedAppsCatalog.defaultOnFirstLaunch) { entry in
                            HStack(spacing: 8) {
                                AppBundleIcon(bundleID: entry.bundleID, size: 28)
                                Text(entry.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SettingsChrome.primaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(14)
            }

            Button {
                onOpenCaptureSettings()
            } label: {
                Label("Manage in Settings → Capture", systemImage: "gearshape")
            }
            .buttonStyle(OnboardingSecondaryButtonStyle(fullWidth: true))
        }
    }

    private var accessibilityExtras: some View {
        VStack(spacing: 14) {
            OnboardingGroupedCard {
                HStack(spacing: 12) {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(accessibilityGranted ? "Accessibility enabled" : "Permission needed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SettingsChrome.primaryText)
                        Text(accessibilityGranted
                             ? "Quick Search can paste into your previous app."
                             : "Enable Quiet Clipboard in System Settings → Privacy & Security → Accessibility.")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsChrome.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }

            if !accessibilityGranted {
                VStack(spacing: 8) {
                    Button("Allow Accessibility…") {
                        AccessibilityPermissionHelper.requestPrompt()
                        refreshAccessibility()
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(fullWidth: true))

                    Button("Open System Settings") {
                        AccessibilityPermissionHelper.openSystemSettings()
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle(fullWidth: true))
                }
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            guard step == .accessibility else { return }
            let granted = AccessibilityPermissionHelper.isGranted
            if granted != accessibilityGranted { accessibilityGranted = granted }
        }
    }

    private var shortcutsExtras: some View {
        VStack(spacing: 8) {
            ForEach(highlightedShortcuts) { row in
                shortcutRow(row)
            }
        }
    }

    private var readyExtras: some View {
        VStack(spacing: 10) {
            Button {
                onTryQuickSearch()
            } label: {
                Label("Try Quick Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fullWidth: true))

            Button {
                onOpenLibrary()
            } label: {
                Label("Open Library", systemImage: "books.vertical")
            }
            .buttonStyle(OnboardingSecondaryButtonStyle(fullWidth: true))

            Text("Reopen this tour anytime from the menu bar → Welcome Tour…")
                .font(.system(size: 11))
                .foregroundStyle(SettingsChrome.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        OnboardingGroupedCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SettingsChrome.primaryText)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsChrome.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func captureTypeChip(_ symbol: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SettingsChrome.accent)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsChrome.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(SettingsChrome.groupedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
        )
    }

    private func shortcutRow(_ row: OnboardingShortcutRow) -> some View {
        OnboardingGroupedCard {
            HStack(spacing: 12) {
                Image(systemName: row.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SettingsChrome.accent)
                    .frame(width: 28, height: 28)
                    .background(SettingsChrome.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SettingsChrome.primaryText)
                    Text(row.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsChrome.tertiaryText)
                }
                Spacer(minLength: 0)
                Text(row.combo)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(SettingsChrome.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }

    private var highlightedShortcuts: [OnboardingShortcutRow] {
        let s = coordinator.shortcutSettings
        func combo(_ action: AppShortcutAction) -> String {
            s.bindings[action]?.displayString ?? AppShortcutAction.defaults[action]?.displayString ?? "—"
        }
        return [
            OnboardingShortcutRow(title: "Quick Search", detail: "Find and paste any clip", combo: combo(.openQuickSearch), systemImage: "magnifyingglass"),
            OnboardingShortcutRow(title: "Library", detail: "Browse full history", combo: combo(.openLibrary), systemImage: "books.vertical"),
            OnboardingShortcutRow(title: "Toggle capture", detail: "Pause or resume saving", combo: combo(.toggleCapture), systemImage: "pause.circle"),
            OnboardingShortcutRow(title: "Paste recent clips", detail: "Slots 1–10 (newest first)", combo: "⌃⌘1 … ⌃⌘0", systemImage: "list.number"),
        ]
    }

    // MARK: - Navigation

    private func goForward() {
        guard stepIndex < OnboardingStep.allCases.count - 1 else { return }
        stepIndex += 1
    }

    private func goBack() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
    }

    private func finishEarly() {
        onComplete()
    }

    private func refreshAccessibility() {
        accessibilityGranted = AccessibilityPermissionHelper.isGranted
    }
}

// MARK: - Shared onboarding chrome

private struct OnboardingGroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsChrome.groupedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
            )
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(SettingsChrome.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(SettingsChrome.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
            )
    }
}
