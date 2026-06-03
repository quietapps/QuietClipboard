# Changelog

All notable changes to **Quiet Clipboard** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version and build numbers match `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `QuietClipboard.xcodeproj` and `QuietClipboard/Info.plist`.

## [0.1.0] — 2026-06-02

Version **0.1.0**

### Build 3

#### Added

- **Pinned clips** — ten permanent slots (separate from favorites and recent-order `Ctrl+Cmd+0–9` paste); assign from Library sidebar **Pinned**, context menu, Quick Search pin control, or **⌥P**; `Ctrl+Option+Cmd+1–0` pastes pinned slots; slots included in JSON export/import
- **Quick Search pinned filter** — **Pinned** chip (icon-only) shows pinned-ordered results and a bottom **Pinned slots** shelf; empty-state hint when no slots are assigned
- **Quick Search selection shortcuts** — **⌥F** favorite, **⌥D** delete, **⌥P** pin/unpin on highlighted item
- **Capture content groups** — Settings → Capture organizes types under **Text**, **Media**, and **Other** with group master toggles
- **Settings from Library** — gear opens macOS Settings reliably from the hosted library window (`SettingsLink` / captured `openSettings`)

#### Changed

- **Fuzzy search performance** — lighter on-device ranker (bounded edit distance, match pool cap, debounced Quick Search refresh); removed NaturalLanguage embedding pass for snappier filtering
- **Uniform grid tiles** — Library and Quick Search grid cards share fixed tile dimensions for even rows
- **Quick Search filter bar** — horizontal pan/drag scroll; **Pinned** and **Favorites** chips are icon-only (tooltips and VoiceOver keep labels)
- **Sensitive previews in popup** — compact redaction mask in list/grid thumbnails instead of oversized reveal panels

#### Fixed

- **Sensitive clip thumbnails** — Reveal overlay no longer breaks layout in Quick Search and menu bar popover rows
- **Library grid layout** — uneven card heights and vertical timestamp text in grid footers
- **Filter bar scrolling** — filter chips scroll horizontally when the bar overflows the panel width
- **Retention** — pinned slot assignments are never removed by age-based cleanup

---

### Build 2

#### Added

- **Fuzzy ranked search** — typo-tolerant search via bounded Levenshtein distance and on-device NaturalLanguage word embeddings; results ranked by match quality, recency (`lastCopiedAt`), and content-type hints; used in Library, Quick Search, and menu bar popover
- **Structured data detection** — auto-badges single-value clips as email, phone, UUID, ISO date, IBAN, IP address, or semver; tap badge to copy normalized form, create a local Reminder (dates), or add a Contact (email/phone)
- **Save but hide (sensitive)** — Settings → Capture option to save sensitive clips with `isSensitive` flag; blurred placeholder in grid, Quick Search, popover, and detail until **Reveal**; copy/paste blocked until revealed
- **Usage stats dashboard** — Settings → Storage charts: copies per day (14 days), top source apps, top content types, busiest hours (from `ClipboardCopyEvent`); all on-device
- **Copy history & near-duplicates** — `ClipboardCopyEvent` tracks each copy; duplicate clips merge with copy count and timeline; library can collapse near-duplicates with **Show N similar** card including its own thumbnail preview
- **Library timeline view** — chronological timeline of clips in the library toolbar view picker
- **Library grouping** — group grid/list by content type, source app, or day
- **Sort by last copied** — library sort uses effective last-copied time from copy events
- **Quick Search popup** — grid/list toggle, per-row favorites and delete, customizable filter bar (which chips appear), horizontal scroll filters, optional preview pane placement (cursor, menu icon, window center, etc.)
- **Menu bar popover** — grid/list toggle and favorites on rows
- **Preview density** — Settings → General: compact (icon + text) vs rich (thumbnails) for list rows and cards
- **Markdown & rich text** — rendered previews for Markdown and RTF; export as `.md` or `.rtf` from detail and context menu
- **Link favicons** — domain favicon on link rows and cards (origin + path fallback)
- **Universal Clipboard** — detects `com.apple.is-remote-clipboard`; tags Handoff items from iPhone/iPad; searchable; optional capture toggle in Settings
- **Auto category suggestions** — on-device suggestions (patterns + optional language analysis) with apply/dismiss banner in detail
- **Storage settings redesign** — overview card, retention picker, age-based manual cleanup with single **Clean up now**, danger-zone actions, backup import/export
- **Library window from Quick Search** — reliable open via dedicated AppKit presenter (menu bar, shortcut, and popup **Library** button)
- **Quick Search cursor placement** — **Open at → Cursor** anchors panel top-left to pointer (not centered)

#### Changed

- **Sensitive `isSensitive` flag** — only set when behavior is **Save but hide** (not when saving normally)
- **Retention cleanup** — age-based manual cleanup uses `effectiveLastCopiedAt` from copy tracking

#### Fixed

- **Quick Search Library button** — no longer only switches to Dock; library window opens correctly from floating panel
- **Quick Search dismiss** — clicks inside panel no longer close it before button actions run
- **Busiest hours chart** — X-axis uses numeric hours with spaced labels (`12a`, `3p`, …) instead of overlapping full time strings

---

### Build 1

Initial release as a Quiet Apps family member.

#### Added

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
- **Settings window** — tabs: General, Capture, Keyboard Shortcuts, Storage, About
- **Pause capture** — suppress all clipboard capture from the menu bar or Settings; menu bar icon shows a dimmed state with a pause badge while active; resume with one click
- **Launch at login** — registers with `SMAppService`; toggle in Settings → General
- **Menu bar agent** — `LSUIElement = true`; no Dock icon by default (library window shows in Dock when open)
- **Privacy-first architecture** — fully offline; zero analytics; zero telemetry; zero accounts; all data stored locally in `~/Library/Application Support/QuietClipboard/` via SwiftData with SQLite backing; the only network operation is optional link preview fetching

---
