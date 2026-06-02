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

    private var quickSearch: FloatingPanelController<AnyView>?
    private var openWindowHandler: ((String) -> Void)?
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
    }

    func setOpenWindowHandler(_ handler: @escaping (String) -> Void) {
        self.openWindowHandler = handler
    }

    private var didBootstrap = false
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
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
            NSApp.activate(ignoringOtherApps: true)
            openWindowHandler?("library")
        case .toggleCapture:
            monitor.setPaused(!monitor.isPaused)
        default:
            if let idx = action.pasteIndex {
                pasteIndex(idx)
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
                        onPaste: { item in self?.paste(item) },
                        onDismiss: { self?.quickSearch?.hide() },
                        onOpenLibrary: {
                            self?.quickSearch?.hide()
                            NSApp.activate(ignoringOtherApps: true)
                            self?.openWindowHandler?("library")
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

    private func paste(_ item: ClipboardItem) {
        let prior = quickSearch?.priorApp ?? PasteSimulator.capturedFrontmost()
        quickSearch?.hide()
        PasteSimulator.pasteAndRestore(item: item, priorApp: prior)
    }

    private func pasteIndex(_ index: Int) {
        let context = ModelContext(container)
        var desc = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        desc.fetchLimit = index + 1
        let items = (try? context.fetch(desc)) ?? []
        guard items.indices.contains(index) else { return }
        let prior = PasteSimulator.capturedFrontmost()
        PasteSimulator.pasteAndRestore(item: items[index], priorApp: prior)
    }
}
