import AppKit
import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let container: ModelContainer
    let monitor: ClipboardMonitor
    let retention: RetentionManager
    @Published var shortcutSettings: ShortcutSettings
    @Published var isPaused: Bool = false
    @Published var pendingSettingsPanel: SettingsPanel?
    @Published private(set) var quickSearchShowCount: Int = 0
    @Published private(set) var revealedSensitiveIDs: Set<UUID> = []
    let pinned = PinnedClipStore.shared

    private var quickSearch: FloatingPanelController<AnyView>?
    private var openWindowHandler: ((String) -> Void)?
    private(set) var openSettings: OpenSettingsAction?
    private var cancellables = Set<AnyCancellable>()

    init(container: ModelContainer) {
        self.container = container
        self.monitor = ClipboardMonitor(modelContainer: container)
        self.retention = RetentionManager(container: container)
        self.shortcutSettings = ShortcutManager.shared.settings
        self.isPaused = monitor.isPaused
        monitor.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.isPaused = v }
            .store(in: &cancellables)
        pinned.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func setOpenWindowHandler(_ handler: @escaping (String) -> Void) {
        self.openWindowHandler = handler
    }

    func setOpenSettings(_ action: OpenSettingsAction) {
        openSettings = action
    }

    func isSensitiveRevealed(_ itemID: UUID) -> Bool {
        revealedSensitiveIDs.contains(itemID)
    }

    func revealSensitive(_ itemID: UUID) {
        guard !revealedSensitiveIDs.contains(itemID) else { return }
        revealedSensitiveIDs.insert(itemID)
    }

    func concealSensitive(_ itemID: UUID) {
        revealedSensitiveIDs.remove(itemID)
    }

    /// First activation on a hidden sensitive clip reveals only; returns whether the action should proceed.
    func shouldProceedWithSensitiveAction(for item: ClipboardItem) -> Bool {
        guard item.isSensitive, !isSensitiveRevealed(item.id) else { return true }
        revealSensitive(item.id)
        return false
    }

    private var didBootstrap = false
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        DataMigrationService.migrateIfNeeded(container: container)
        pinned.pruneMissingItems(context: ModelContext(container))
        ExcludedAppsCatalog.seedDefaultsIfNeeded()
        FrontmostAppTracker.shared.start()
        PasteSimulator.onAccessibilityNeeded = { [weak self] in
            // Fallback hook — paste-time AX revocation. Pre-paste gate above normally catches it.
            self?.presentAccessibilityGateIfNeeded()
        }
        monitor.start()
        retention.start()
        ShortcutManager.shared.onAction = { [weak self] action in
            self?.handle(action)
        }
        ShortcutManager.shared.install()
        presentOnboardingIfNeeded()
        // If auto-paste is on but Accessibility hasn't been granted, present a blocking gate
        // window after launch. Window polls AX every second and auto-dismisses when granted, so
        // the user never hits a paste flow that silently fails or freezes the UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.presentAccessibilityGateIfNeeded()
        }
        // Pre-build Quick Search panel so first open is instant.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.prebuildQuickSearch()
        }
    }

    private func prebuildQuickSearch() {
        if quickSearch == nil {
            let container = self.container
            let coord = self
            let controller = FloatingPanelController(width: 1060, height: 480) { [weak self] in
                AnyView(
                    QuickSearchOverlay(
                        onPaste: { item in self?.pasteFromQuickSearch(item) },
                        onPlainPaste: { item in self?.pasteFromQuickSearch(item, asPlainText: true) },
                        onDismiss: { self?.quickSearch?.hide(restoreFocus: true) },
                        onOpenLibrary: {
                            self?.quickSearch?.hide()
                            self?.openLibraryWindow()
                        },
                        onTogglePause: { self?.monitor.setPaused(!(self?.monitor.isPaused ?? false)) },
                        onQuit: { NSApp.terminate(nil) }
                    )
                    .environmentObject(coord)
                    .environmentObject(coord.monitor)
                    .modelContainer(container)
                )
            }
            controller.onWillShow = { [weak self] in
                self?.quickSearchShowCount += 1
            }
            quickSearch = controller
        }
        quickSearch?.prebuild()
    }

    func presentOnboarding(force: Bool = false) {
        OnboardingWindowPresenter.shared.present(coordinator: self, force: force)
    }

    func presentOnboardingIfNeeded() {
        guard !Preferences.hasCompletedOnboarding else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.presentOnboarding()
        }
    }

    func openSettings(panel: SettingsPanel) {
        pendingSettingsPanel = panel
        openSettings?()
    }

    func toggleQuickSearchForOnboarding() {
        toggleQuickSearch()
    }

    /// Opens the Quick Search overlay (used by the menu bar popover's search button).
    func openQuickSearch() {
        toggleQuickSearch()
    }

    /// Pastes a clip chosen from the menu bar popover into the previously-frontmost app.
    func pasteFromMenuBar(_ item: ClipboardItem) {
        let context = ModelContext(container)
        pasteItem(item, context: context)
    }

    private func handle(_ action: AppShortcutAction) {
        switch action {
        case .openQuickSearch:
            toggleQuickSearch()
        case .openLibrary:
            openLibraryWindow()
        case .toggleCapture:
            monitor.setPaused(!monitor.isPaused)
        default:
            if let idx = action.pasteIndex {
                pasteIndex(idx)
            } else if let slot = action.pastePinnedSlot {
                pastePinnedSlot(slot)
            }
        }
    }

    func resetQuickSearchSize() {
        Preferences.quickSearchLastSize = nil
        quickSearch?.resetSize()
    }

    /// Whether the Quick Search panel is currently on screen. The overlay view stays alive
    /// while hidden and uses this to skip list-refresh work nobody can see.
    var isQuickSearchPanelVisible: Bool {
        quickSearch?.isVisible ?? false
    }

    private func toggleQuickSearch() {
        // AX is checked at launch; not re-checked here so opening stays instant. Paste-time guard
        // in `pasteFromQuickSearch` handles late-revoked permission by falling back to copy-only.
        prebuildQuickSearch()
        quickSearch?.toggle()
    }

    /// Whether auto-paste-into-prior-app is the active mode (pref on AND Accessibility granted).
    /// When false, clip selections only copy to the system clipboard.
    private var canAutoPaste: Bool {
        Preferences.autoPasteEnabled && AccessibilityPermissionHelper.isGranted
    }

    /// Presents the blocking Accessibility gate window when auto-paste is enabled but permission
    /// is missing. Returns true if the gate was shown — callers should bail in that case.
    @discardableResult
    func presentAccessibilityGateIfNeeded() -> Bool {
        guard Preferences.autoPasteEnabled else { return false }
        return AccessibilityGate.presentIfNeeded(coordinator: self)
    }

    func pasteFromQuickSearch(_ item: ClipboardItem, asPlainText: Bool = false) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        let prior = quickSearch?.priorApp ?? PasteSimulator.capturedFrontmost()
        // Restore focus to the prior app on dismiss — in the copy-only path the user must be
        // able to press ⌘V right away without clicking back into their window.
        quickSearch?.hide(restoreFocus: true)
        let context = ModelContext(container)

        // Copy-only path: auto-paste disabled OR Accessibility missing. Skips the activate +
        // synthesized ⌘V chain (which would silently no-op when AX is missing). User pastes
        // with ⌘V manually. No prior-clipboard snapshot, no UI freeze.
        guard canAutoPaste else {
            // Auto-paste off OR AX missing: copy only, no paste chain. Avoids the hang.
            if asPlainText {
                ClipboardItemUsage.copyPlainTextToPasteboard(item, context: context, monitor: monitor)
            } else {
                ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
            }
            if Preferences.autoPasteEnabled {
                // AX missing while auto-paste expected — present the gate (clip is on clipboard).
                presentAccessibilityGateIfNeeded()
            } else {
                showCopiedHUD()
            }
            return
        }

        ClipboardItemDelivery.deliver(item, priorApp: prior, context: context, monitor: monitor, asPlainText: asPlainText)
        showPasteHUD()
    }

    private func showPasteHUD() {
        guard Preferences.showPasteFeedbackHUD else { return }
        FeedbackHUD.shared.show("Pasted", systemImage: "checkmark.circle.fill", duration: 0.85)
    }

    private func showCopiedHUD() {
        guard Preferences.showPasteFeedbackHUD else { return }
        FeedbackHUD.shared.show("Copied — press ⌘V to paste", systemImage: "doc.on.clipboard.fill", duration: 1.1)
    }

    /// Strips formatting and pastes the plain-text form into the prior app.
    func pastePlainText(_ item: ClipboardItem) {
        pasteFromQuickSearch(item, asPlainText: true)
    }

    func typeFromQuickSearch(_ item: ClipboardItem) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard let text = PasteSimulator.plainText(from: item) else {
            pasteFromQuickSearch(item)
            return
        }
        let prior = quickSearch?.priorApp ?? PasteSimulator.capturedFrontmost()
        quickSearch?.hide(restoreFocus: true)
        let context = ModelContext(container)
        ClipboardItemDelivery.deliverWithAutoType(text, item: item, priorApp: prior, context: context, monitor: monitor)
    }

    func openLibraryWindow() {
        LibraryWindowPresenter.shared.present(coordinator: self)
    }

    private func pasteIndex(_ index: Int) {
        let context = ModelContext(container)
        // Bound the fetch — paste-by-index only needs the few most-recent clips, not the whole
        // history materialized (which would fault every clip's content blob).
        var desc = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
        desc.fetchLimit = 60
        let items = ((try? context.fetch(desc)) ?? [])
            .sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
        guard index < items.count else { return }
        pasteItem(items[index], context: context)
    }

    private func pastePinnedSlot(_ slot: Int) {
        let context = ModelContext(container)
        guard let item = pinned.resolveItem(slot: slot, context: context) else { return }
        pasteItem(item, context: context)
    }

    private func pasteItem(_ item: ClipboardItem, context: ModelContext, asPlainText: Bool = false) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        let prior = PasteSimulator.capturedFrontmost()
        guard canAutoPaste else {
            if asPlainText {
                ClipboardItemUsage.copyPlainTextToPasteboard(item, context: context, monitor: monitor)
            } else {
                ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
            }
            if Preferences.autoPasteEnabled {
                presentAccessibilityGateIfNeeded()
            } else {
                showCopiedHUD()
            }
            return
        }
        ClipboardItemDelivery.deliver(item, priorApp: prior, context: context, monitor: monitor, asPlainText: asPlainText)
        showPasteHUD()
    }

    func typeItem(_ item: ClipboardItem) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard let text = PasteSimulator.plainText(from: item) else { return }
        let context = ModelContext(container)
        let prior = PasteSimulator.capturedFrontmost()
        ClipboardItemDelivery.deliverWithAutoType(text, item: item, priorApp: prior, context: context, monitor: monitor)
    }

    // MARK: - Image clip actions

    /// Copies the OCR text of an image clip — either the layout-preserved form (exact
    /// indentation/columns as seen in the image) or a whitespace-cleaned form. The write is
    /// intentionally NOT acknowledged so the monitor captures it as a new text clip.
    func copyOCRText(_ item: ClipboardItem, cleaned: Bool) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard let ocr = item.ocrText, !ocr.isEmpty else { return }
        let text = cleaned ? OCRService.cleanedText(from: ocr) : ocr
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        FeedbackHUD.shared.show(cleaned ? "Cleaned text copied" : "Text copied (exact layout)",
                                systemImage: "text.viewfinder", duration: 1.0)
    }

    enum ImageClipAction {
        case resize(ImageTransformService.ResizeOption)
        case removeBackground
    }

    /// Runs a transform on an image clip and puts the result on the pasteboard as PNG. The
    /// write is NOT acknowledged so the monitor ingests it as a new clip (with thumbnail,
    /// OCR, and dedupe via the normal pipeline).
    func performImageAction(_ item: ClipboardItem, action: ImageClipAction) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard item.contentType == .image || item.contentType == .screenshot else { return }
        let data = item.content
        if case .removeBackground = action {
            FeedbackHUD.shared.show("Removing background…", systemImage: "wand.and.stars", duration: 1.4)
        }
        Task { [weak self] in
            let result: Data?
            let successMessage: String
            switch action {
            case .resize(let option):
                result = await Task.detached(priority: .userInitiated) {
                    ImageTransformService.resized(data, option: option)
                }.value
                successMessage = "Resized image copied"
            case .removeBackground:
                result = await ImageTransformService.removingBackground(data)
                successMessage = "Background removed — image copied"
            }
            await MainActor.run {
                guard self != nil else { return }
                guard let result else {
                    let message: String
                    if case .removeBackground = action {
                        message = "No subject found to cut out"
                    } else {
                        message = "Couldn’t process image"
                    }
                    FeedbackHUD.shared.show(message,
                                            systemImage: "exclamationmark.triangle.fill",
                                            isWarning: true, duration: 1.6)
                    return
                }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(result, forType: .png)
                FeedbackHUD.shared.show(successMessage, systemImage: "checkmark.circle.fill", duration: 1.1)
            }
        }
    }
}
