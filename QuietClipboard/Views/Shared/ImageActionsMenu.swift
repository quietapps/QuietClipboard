import AppKit
import SwiftUI

/// Context-menu actions for image/screenshot clips: copy recognized text (exact layout or
/// cleaned), resize, remove background, and convert-and-save. Renders nothing for other types.
struct ImageActionsMenu: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem

    private var isImage: Bool {
        item.contentType == .image || item.contentType == .screenshot
    }

    private var isRedacted: Bool {
        item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
    }

    var body: some View {
        if isImage, !isRedacted {
            if let ocr = item.ocrText, !ocr.isEmpty {
                Menu {
                    Button {
                        coordinator.copyOCRText(item, cleaned: false)
                    } label: {
                        Label("Exact Layout", systemImage: "text.alignleft")
                    }
                    Button {
                        coordinator.copyOCRText(item, cleaned: true)
                    } label: {
                        Label("Cleaned Up", systemImage: "text.badge.checkmark")
                    }
                } label: {
                    Label("Copy Text from Image", systemImage: "text.viewfinder")
                }
            }

            Menu {
                ForEach([0.75, 0.5, 0.25], id: \.self) { factor in
                    Button("\(Int(factor * 100))%") {
                        coordinator.performImageAction(item, action: .resize(.scale(factor)))
                    }
                }
                Divider()
                ForEach([2048.0, 1024.0, 512.0, 256.0], id: \.self) { px in
                    Button("Fit \(Int(px)) px") {
                        coordinator.performImageAction(item, action: .resize(.fit(px)))
                    }
                }
            } label: {
                Label("Resize & Copy", systemImage: "arrow.down.right.and.arrow.up.left")
            }

            Button {
                coordinator.performImageAction(item, action: .removeBackground)
            } label: {
                Label("Remove Background", systemImage: "person.and.background.dotted")
            }

            Menu {
                ForEach(ImageTransformService.ExportFormat.allCases) { format in
                    Button("Save as \(format.displayName)…") {
                        ImageConvertPanel.present(for: item, format: format)
                    }
                }
            } label: {
                Label("Convert & Save", systemImage: "square.and.arrow.down")
            }
        }
    }
}

/// Convert-and-save flow for the menu above: conversion runs off-main, then an `NSSavePanel`
/// collects the destination. Lives here rather than in `ImageTransformService` so the service
/// stays free of app types (`ClipboardItem`, `FeedbackHUD`) and can compile into the
/// standalone unit-test bundle.
private enum ImageConvertPanel {
    @MainActor
    static func present(for item: ClipboardItem, format: ImageTransformService.ExportFormat) {
        let data = item.content
        let baseName = (item.title?.isEmpty == false ? item.title! : "Image")
            .replacingOccurrences(of: "/", with: "-")
        DispatchQueue.global(qos: .userInitiated).async {
            guard let converted = ImageTransformService.converted(data, to: format) else {
                DispatchQueue.main.async {
                    FeedbackHUD.shared.show("Couldn’t convert image",
                                            systemImage: "exclamationmark.triangle.fill",
                                            isWarning: true, duration: 1.6)
                }
                return
            }
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.allowedContentTypes = [format.utType]
                panel.nameFieldStringValue = "\(baseName).\(format.fileExtension)"
                panel.begin { response in
                    guard response == .OK, let dest = panel.url else { return }
                    do {
                        try converted.write(to: dest)
                        FeedbackHUD.shared.show("Saved as \(format.displayName)",
                                                systemImage: "checkmark.circle.fill", duration: 1.0)
                    } catch {
                        NSLog("Image convert save failed: \(error)")
                        FeedbackHUD.shared.show("Couldn’t save image",
                                                systemImage: "exclamationmark.triangle.fill",
                                                isWarning: true, duration: 1.6)
                    }
                }
            }
        }
    }
}
