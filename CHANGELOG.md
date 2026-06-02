# Changelog

All notable changes to **Quiet Clipboard** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0] — 2026-06-02

**Build 1** · Initial release as a Quiet Apps family member.

### Added

- **Clipboard monitor** — background actor polls `NSPasteboard.general` every ~0.5 seconds and captures every change automatically; duplicate copies are skipped
- **Content type detection** — classifies each item as text, rich text, image, screenshot, link, file, code, color, or SVG using type identifiers and content heuristics; each item is badged with its type
- **Quick search overlay** — `Ctrl+Cmd+V` opens a Spotlight-style floating panel with a search field; real-time filtering across text content, OCR text, titles, source app names, and category names; arrow keys navigate, Enter pastes, Escape dismisses
- **Notch shelf / Dynamic Island panel** — `Ctrl+Cmd+N` surfaces a floating horizontal row of the most recent clips from the notch or as an expanding pill at the top of the screen; drag any clip directly into any app; click to copy; right-click for actions
- **Full library window** — `Ctrl+Cmd+L` opens a dedicated window with a sidebar (History, Favorites, Screenshots, custom categories with item counts), a grid/list content area, toolbar search, sort by date/type/size/source app, multi-select with Cmd/Shift+Click, and Quick Look via Space
- **Menu bar popover** — clipboard icon in the menu bar shows the last 10–15 items with type previews, a search field, and quick actions (Pause, Open Library, Settings)
- **Code highlighting** — syntax-highlighted previews with automatic language detection (Swift, Python, JavaScript, JSON, HTML, CSS, Shell, and more); language badge shown on each code item
- **Color swatches** — parses `#hex`, `rgb()`, `rgba()`, `hsl()`, `hsla()`, and named CSS colors; renders a color swatch preview; detail panel lets you copy in any format via right-click
- **Link previews** — `LPMetadataProvider` fetches title, description, and preview image for copied URLs; results are cached so the same URL is never fetched twice; falls back gracefully to the raw URL; toggleable in Settings → Capture
- **OCR on images** — Vision framework runs `VNRecognizeTextRequest` (`.accurate`, `.automaticallyDetectsLanguage`) on every captured image and screenshot; extracted text stored in `ocrText` and fully searchable
- **Sensitive content detection** — on-device detection of passwords (`org.nspasteboard.ConcealedType`), API keys (`sk-`, `pk_`, `AKIA`, `ghp_`, `github_pat_`, `xox[bpas]-`, `Bearer `), private keys (`-----BEGIN.*PRIVATE KEY-----`), SSH keys, JWTs, credit card numbers (Luhn check), `.env` key=value pairs, and AWS/Stripe/Slack tokens; default behavior is not to save; configurable per preference in Settings → Capture
- **Thumbnails** — generated for every item at capture time: images scaled to 200px wide, text shows first lines, links show preview image, colors show full swatch, code shows syntax-highlighted excerpt; lazy-loaded in grid views
- **Favorites** — star any item; favorites are excluded from all automatic retention cleanup
- **Custom categories** — create named categories with an SF Symbol icon and custom color; drag items into categories; items can belong to multiple categories; right-click a category to rename, change icon/color, or delete (items are not deleted when a category is deleted)
- **Retention and cleanup** — configurable auto-cleanup: 7, 15, 30, or 90 days, or never; runs daily and on launch; favorites are always preserved; manual clear by type, by age threshold, or all at once (requires confirmation)
- **Keyboard shortcuts** — six remappable global actions: Open Quick Search (`Ctrl+Cmd+V`), Open Notch/Island (`Ctrl+Cmd+N`), Open Library (`Ctrl+Cmd+L`), Toggle capture (`Ctrl+Cmd+P`), and Paste clip 1–10 (`Ctrl+Cmd+0`–`9`); conflict detection against internal and known system shortcuts; visual key recorder ("Press your shortcut…"); reset to defaults
- **Source app tracking** — captures `NSWorkspace.shared.frontmostApplication` at copy time; source app icon and name displayed on each item across all UI surfaces
- **Item detail panel** — full content preview, metadata (source app, timestamp, size, type), editable text content, collapsible OCR text section, and action buttons (Copy, Paste, Favorite, Categorize, Delete, Share)
- **Drag and drop** — all surfaces (library grid, notch shelf, island panel) support dragging items into any app via `Transferable`; library supports dragging items into category sidebar to categorize
- **Export / Import** — full clipboard history exportable as JSON with all metadata; import restores items including content, type, source app, favorites flag, and timestamps
- **WidgetKit widgets** — Small widget (last 3 items, compact list), Medium widget (last 6 items, 2-column grid with type badges), and Large widget (last 10–12 items, grid with Search button and category tabs); all interactive via AppIntents on macOS 15
- **Settings window** — five tabs: General (launch at login, menu bar icon style, notch/island mode, default view, sound on copy), Capture (pause toggle, content type checkboxes, excluded apps list, sensitive detection behavior), Keyboard Shortcuts (full remapping UI), Storage (retention picker, usage display, clear and export/import actions), About (version, license, GitHub link)
- **Pause capture** — suppress all clipboard capture from the menu bar or Settings; menu bar icon shows a dimmed state with a pause badge while active; resume with one click
- **Launch at login** — registers with `SMAppService`; toggle in Settings → General
- **Menu bar agent** — `LSUIElement = true`; no Dock icon, no app switcher entry
- **Privacy-first architecture** — fully offline; zero analytics; zero telemetry; zero accounts; all data stored locally in `~/Library/Application Support/QuietClipboard/` via SwiftData with SQLite backing; the only network operation is optional link preview fetching

---
