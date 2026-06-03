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
        monitor.start()
        retention.start()
        ShortcutManager.shared.onAction = { [weak self] action in
            self?.handle(action)
        }
        ShortcutManager.shared.install()
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

    private func toggleQuickSearch() {
        if quickSearch == nil {
            let container = self.container
            let coord = self
            quickSearch = FloatingPanelController(width: 1060, height: 480) { [weak self] in
                AnyView(
                    QuickSearchOverlay(
                        onPaste: { item in self?.pasteFromQuickSearch(item) },
                        onDismiss: { self?.quickSearch?.hide() },
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
        }
        quickSearch?.toggle()
    }

    func pasteFromQuickSearch(_ item: ClipboardItem) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        let prior = quickSearch?.priorApp ?? PasteSimulator.capturedFrontmost()
        quickSearch?.hide()
        let context = ModelContext(container)
        ClipboardItemDelivery.deliver(item, priorApp: prior, context: context, monitor: monitor)
    }

    func typeFromQuickSearch(_ item: ClipboardItem) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard let text = PasteSimulator.plainText(from: item) else {
            pasteFromQuickSearch(item)
            return
        }
        let prior = quickSearch?.priorApp ?? PasteSimulator.capturedFrontmost()
        quickSearch?.hide()
        let context = ModelContext(container)
        ClipboardItemDelivery.deliverWithAutoType(text, item: item, priorApp: prior, context: context, monitor: monitor)
    }

    func openLibraryWindow() {
        LibraryWindowPresenter.shared.present(coordinator: self)
    }

    private func pasteIndex(_ index: Int) {
        let context = ModelContext(container)
        let items = ((try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? [])
            .sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
        guard index < items.count else { return }
        pasteItem(items[index], context: context)
    }

    private func pastePinnedSlot(_ slot: Int) {
        let context = ModelContext(container)
        guard let item = pinned.resolveItem(slot: slot, context: context) else { return }
        pasteItem(item, context: context)
    }

    private func pasteItem(_ item: ClipboardItem, context: ModelContext) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        let prior = PasteSimulator.capturedFrontmost()
        ClipboardItemDelivery.deliver(item, priorApp: prior, context: context, monitor: monitor)
    }

    func typeItem(_ item: ClipboardItem) {
        guard shouldProceedWithSensitiveAction(for: item) else { return }
        guard let text = PasteSimulator.plainText(from: item) else { return }
        let context = ModelContext(container)
        let prior = PasteSimulator.capturedFrontmost()
        ClipboardItemDelivery.deliverWithAutoType(text, item: item, priorApp: prior, context: context, monitor: monitor)
    }
}
