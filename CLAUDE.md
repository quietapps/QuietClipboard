# Quiet Clipboard

Bundle ID: `app.quiet.QuietClipboard`
App Name: `Quiet Clipboard.app`

## Project Overview

Native macOS clipboard history manager. Swift + SwiftUI. Saves everything copied (text, images, links, files, code, colors, screenshots, rich text, SVGs) into a local searchable visual history. Fully offline, privacy-first. SwiftData with SQLite backing. MIT licensed. Minimum target: macOS 15.0 (Sequoia).

## Architecture

- Language: Swift 5.9+
- UI: SwiftUI (entire app)
- Data: SwiftData with SQLite backing. Store at `~/Library/Application Support/QuietClipboard/`
- Concurrency: async/await, actors. Clipboard monitor on background actor. Never block main thread.
- Lifecycle: Menu bar app (`LSUIElement = true`). No Dock icon by default. UI surfaces: (1) menu bar popover, (2) notch shelf / Dynamic Island floating panel, (3) quick search overlay, (4) full Library window.
- Single Xcode project, minimal external deps. Prefer Apple frameworks (Vision, LinkPresentation, NaturalLanguage).

## Core Data Model (SwiftData)

### ClipboardItem

- `id: UUID`
- `content: Data` — raw clipboard content (binary)
- `contentType: ClipboardContentType` — enum: `.text`, `.richText`, `.image`, `.screenshot`, `.link`, `.file`, `.code`, `.color`, `.svg`, `.other`
- `textContent: String?` — extracted plain text (for search)
- `ocrText: String?` — OCR text from images/screenshots
- `title: String?` — display title (first line, filename, link title, etc.)
- `sourceAppBundleID: String?`
- `sourceAppName: String?`
- `thumbnailData: Data?`
- `linkPreviewTitle: String?`
- `linkPreviewDescription: String?`
- `linkPreviewImageData: Data?`
- `colorHex: String?`
- `fileSize: Int64?`
- `fileMIMEType: String?`
- `isFavorite: Bool` — default false
- `isSensitive: Bool`
- `categories: [Category]`
- `createdAt: Date`
- `modifiedAt: Date`

### Category

- `id: UUID`
- `name: String`
- `icon: String` — SF Symbol
- `color: String` — hex
- `sortOrder: Int`
- `items: [ClipboardItem]` — inverse
- `createdAt: Date`

### AppSettings (`@AppStorage` / UserDefaults)

- Keyboard shortcuts (all remappable)
- Retention period: 7, 15, 30, 90 days, unlimited
- Capture enabled/paused
- Content type filters
- Sensitive detection enabled
- Notch mode: `.notch` or `.dynamicIsland`
- Max history size
- Launch at login
- Show in menu bar
- Sound on copy (off by default)

## Feature 1: Clipboard Monitoring

Poll `NSPasteboard.general` ~0.5s on background actor.

On change:
1. Read all pasteboard types
2. Detect content type
3. Skip duplicates
4. Run sensitive detection (if enabled)
5. If sensitive + detection enabled: mark `isSensitive = true`, optionally skip
6. Extract plain text for search
7. Detect source app via `NSWorkspace.shared.frontmostApplication`
8. Generate thumbnail (image ~200px; text first lines; link preview; color swatch; code syntax preview)
9. If image: run OCR via Vision
10. If URL: fetch link preview via `LPMetadataProvider`
11. Persist `ClipboardItem`
12. Post notification

Content type detection:
- `.string` → check URL, hex color (`#RRGGBB`/`rgb()`), code (heuristics: `{`, `func `, `def `, `class `, `import `, `const `, `let `, `var `, `=>`, `->`), or plain text
- `.rtf`/`.rtfd` → rich text
- `.png`/`.tiff` → image or screenshot
- File URLs → file
- `<svg` in text → SVG
- Color values → color

Pause/Resume via menu bar or settings. Show visual indicator when paused.

## Feature 2: Sensitive Content Detection

On-device only. No network.

Detect:
- Passwords (`org.nspasteboard.ConcealedType`)
- API keys (`sk-`, `pk_`, `api_key=`, `AKIA`, `ghp_`, `gho_`, `github_pat_`, `xox[bpas]-`, `Bearer `)
- Private keys (`-----BEGIN.*PRIVATE KEY-----`)
- SSH keys (`ssh-rsa`, `ssh-ed25519`, `ecdsa-sha2-`)
- JWT (`eyJ...`)
- Credit cards (Luhn on 13-19 digit sequences)
- `.env` content (`KEY=VALUE` with sensitive names: `SECRET`, `PASSWORD`, `TOKEN`, `API_KEY`, `DATABASE_URL`)
- AWS, Stripe, Slack tokens

Default: NOT saved. Settings: (a) don't save, (b) save but blur, (c) save normally.

## Feature 3: Notch Shelf / Dynamic Island Panel

Floating panel at top center. Two modes:

### Notch Mode
- Panel extends from notch downward
- Horizontal row of recent thumbnails
- Drag and drop into any app
- Hover preview, click to copy
- Shortcut: `Ctrl+Cmd+N`

### Dynamic Island Mode (default)
- Compact pill at top center
- Expands on hover or shortcut
- Same drag/click behavior
- Works on all Macs

Both:
- Last 5-10 items as cards
- Drag/drop into any app
- Click to paste
- Right-click: favorite, delete, categorize, copy
- Dismiss outside click / Escape
- `NSPanel`, `.floating`, non-activating

## Feature 4: Quick Search Overlay

Spotlight-style, default `Ctrl+Cmd+V`.

- Centered floating panel, search field at top
- Real-time filter across all items
- Matches: `textContent`, `ocrText`, `title`, `linkPreviewTitle`, `sourceAppName`, `colorHex`, `categories.name`
- Grid/list with previews
- Arrow keys navigate, Enter pastes, Escape dismisses
- Filter bar: Text, Images, Links, Code, Colors, Files, Screenshots
- Source app icon next to results
- Non-activating `NSPanel`. Remembers prior focused app, pastes into it

## Feature 5: Full Library Window

Layout:
- Sidebar: History, Favorites, Screenshots, divider, user categories. Count badges.
- Main: grid of cards, most recent first
- Toolbar: search, view toggle (grid/list), sort (date/type/size/app), filter by app

Cards:
- Visual preview (image thumb, text, color swatch, file icon, code with highlighting, link card)
- Source app icon (small, bottom-left)
- Relative timestamp
- File size where applicable
- Favorite star
- Content type badge

Interactions:
- Click → copy
- Double-click → detail panel
- Right-click: Copy, Paste, Favorite, Categorize, Delete, Share, Quick Look
- Drag/drop out
- Multi-select Cmd/Shift+Click for bulk

Categories:
- `+` button in sidebar
- Right-click rename/icon/color/delete (items NOT deleted on category delete)
- Drag items into categories
- Item can belong to multiple

Detail panel:
- Full content preview
- Metadata: source app, timestamp, size, type, OCR text
- Editable text content
- Actions: Copy, Paste, Favorite, Categorize, Delete, Share

## Feature 6: Menu Bar App

Custom icon (clipboard + Q badge).

Popover:
- Last 10-15 items with previews
- Search field
- Quick actions: Pause/Resume, Open Library, Settings
- Click item → copy, hover → preview
- Footer: Open Library, pause toggle, settings

Icon states:
- Normal
- Paused (dimmed / pause badge)
- New item captured: subtle animation (optional)

## Feature 7: Keyboard Shortcuts (Remappable)

| Action | Default |
|--------|---------|
| Open Quick Search | `Ctrl+Cmd+V` |
| Open Notch/Island | `Ctrl+Cmd+N` |
| Open Library | `Ctrl+Cmd+L` |
| Paste clip 1-10 | `Ctrl+Cmd+0` … `Ctrl+Cmd+9` |
| Toggle capture | `Ctrl+Cmd+P` |
| Clear history | none (safety) |

Remapping UI:
- List actions + current shortcut
- Click to record new
- Visual recorder: "Press your shortcut…"
- Conflict detection (internal + known system)
- Reset to defaults
- Global hotkeys via `NSEvent.addGlobalMonitorForEvents` + `CGEventTap`, no external deps

## Feature 8: OCR

Vision framework on image capture.

- `VNRecognizeTextRequest` with `.accurate`
- Store in `ocrText`
- Searchable
- Async background queue
- `.automaticallyDetectsLanguage = true`
- Show as collapsible section in detail

## Feature 9: Link Previews

LinkPresentation.

- `LPMetadataProvider().startFetchingMetadata(for:)`
- Extract title, description, image, icon
- Store in `linkPreviewTitle`, `linkPreviewDescription`, `linkPreviewImageData`
- Rich card across all UI surfaces
- Cache (no refetch same URL)
- Fail gracefully → raw URL
- ONLY network operation in app. Toggleable in Settings.

## Feature 10: macOS Widgets

WidgetKit.

- Small: last 3 items, compact list. Tap → open + copy
- Medium: last 6, 2-col grid with previews + type badge
- Large: last 10-12 grid, Search button, category tabs

Use `AppIntents` for interactivity on macOS 15.

## Feature 11: Retention & Management

- Retention: 7/15/30/90 days or Forever. Default 30.
- Auto-cleanup daily / on launch. Favorites NEVER auto-deleted.
- Manual: Clear all (confirm), Clear non-favorited, Clear older than X, Delete by type
- Storage display in Settings
- Export as JSON
- Import JSON backup

## Feature 12: Settings Window

SwiftUI `Settings` scene. Tabs:

### General
- Launch at login
- Menu bar icon style
- Notch/Island mode picker
- Default view (grid/list)
- Sound on copy

### Capture
- Pause/Resume
- Content types checkboxes (Text, Rich Text, Images, Screenshots, Links, Files, Code, Colors, SVG)
- Excluded apps list
- Sensitive detection toggle + behavior (Don't save / Save hidden / Save normally)

### Keyboard Shortcuts
- Full remapping UI
- Key recorder per action
- Conflict detection
- Reset defaults

### Storage
- Retention picker
- Usage display
- Clear buttons
- Export/Import

### About
- Version, build
- MIT license
- GitHub link
- Credits

## Feature 13: Content Type Behaviors

### Text
- 2-3 line preview, full in detail
- Detect/badge: plain, email, phone, address

### Code
- Syntax highlighting (regex or `NSAttributedString` with monospace + keyword colors)
- Detect language
- Language badge (Swift, Python, JS, JSON, HTML, CSS, Shell, etc.)

### Colors
- Parse hex (`#RRGGBB`, `#RGB`), `rgb()`, `rgba()`, `hsl()`, `hsla()`, named CSS
- Color swatch preview
- Detail shows all formats
- Right-click → copy as hex/rgb/hsl

### Images / Screenshots
- Thumbnails max 200px wide
- Dimensions + size
- Quick Look on space
- OCR

### Links / URLs
- Rich preview card (title, description, image)
- Domain as subtitle
- Right-click → open in browser

### Files
- Icon via `NSWorkspace`
- Filename, size, type
- Quick Look on space
- Reveal in Finder

### SVG
- Render in WebView or convert to image
- Show SVG code in detail

## UI/UX

- Clean, minimal, macOS-native. SF Symbols. Apple HIG.
- Light + dark mode. Semantic colors. Customizable accent.
- System fonts. Monospace for code.
- Subtle `.spring()` animations.
- Full VoiceOver. Accessibility labels. Dynamic Type. Keyboard navigable.
- `Transferable` for drag/drop across all surfaces.
- Performance: search < 50ms. `@Query` predicates. Lazy thumbnails. Paginate 50 items.

## Project Structure

```
QuietClipboard/
├── QuietClipboardApp.swift          — entry, app delegate, menu bar
├── Models/
│   ├── ClipboardItem.swift
│   ├── Category.swift
│   └── ClipboardContentType.swift
├── Services/
│   ├── ClipboardMonitor.swift
│   ├── SensitiveDetector.swift
│   ├── OCRService.swift
│   ├── LinkPreviewService.swift
│   ├── ContentTypeDetector.swift
│   ├── ThumbnailGenerator.swift
│   ├── ShortcutManager.swift
│   ├── RetentionManager.swift
│   └── ExportImportService.swift
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift
│   │   └── MenuBarPopover.swift
│   ├── NotchPanel/
│   │   ├── NotchShelfView.swift
│   │   └── DynamicIslandView.swift
│   ├── QuickSearch/
│   │   └── QuickSearchOverlay.swift
│   ├── Library/
│   │   ├── LibraryWindow.swift
│   │   ├── LibrarySidebar.swift
│   │   ├── ClipboardItemGrid.swift
│   │   ├── ClipboardItemRow.swift
│   │   ├── ClipboardItemCard.swift
│   │   └── ItemDetailView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsTab.swift
│   │   ├── CaptureSettingsTab.swift
│   │   ├── ShortcutSettingsTab.swift
│   │   ├── StorageSettingsTab.swift
│   │   └── ShortcutRecorderView.swift
│   └── Shared/
│       ├── ClipboardItemPreview.swift
│       ├── ColorSwatchView.swift
│       ├── CodePreviewView.swift
│       └── LinkPreviewCard.swift
├── Widgets/
│   ├── QuietClipboardWidget.swift
│   ├── SmallWidget.swift
│   ├── MediumWidget.swift
│   └── LargeWidget.swift
├── Utilities/
│   ├── PasteboardHelper.swift
│   ├── DateFormatting.swift
│   └── ColorParsing.swift
├── Resources/
│   └── Assets.xcassets
└── Info.plist
```

## Build Phases

1. **Foundation**: SwiftData models, ClipboardMonitor, menu bar popover with recent clips. Text/image capture.
2. **Library**: Full window, sidebar, grid/list, search, filter, favorites, detail.
3. **Quick Search & Shortcuts**: overlay, global hotkeys, Ctrl+Cmd+0-9 paste, remapping UI.
4. **Notch/Island**: shelf + island with drag/drop.
5. **Intelligence**: sensitive detection, OCR, link previews, type-specific rendering.
6. **Categories & Management**: custom categories, retention, export/import, storage.
7. **Widgets & Polish**: WidgetKit, accessibility, animations, perf.

## Privacy

Local-first. ZERO analytics. ZERO telemetry. ZERO cloud. ZERO accounts. Only network call: `LPMetadataProvider`. Toggleable. All data in `~/Library/Application Support/QuietClipboard/`.
