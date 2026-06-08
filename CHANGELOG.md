# Changelog

All notable changes to **Quiet Clipboard** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version and build numbers match `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `QuietClipboard.xcodeproj` and `QuietClipboard/Info.plist`.


## [0.2.1] — 2026-06-08

Version **0.2.1**

### Build 2

#### Added

- **Automatic database recovery** — if the clipboard store is ever corrupted or fails to open, the app now quarantines the old database into a timestamped `Recovered-…` folder and starts fresh instead of failing to launch; if even that fails it runs in temporary memory and tells you. Your data is preserved, never silently lost.
- **Capture-failure warning** — a brief on-screen warning now appears if a copied item can't be saved, so a lost clip is never silent.

#### Changed

- **Faster, lighter image previews** — image and screenshot thumbnails now decode off the main thread, downsampled and cached, so scrolling an image-heavy history stays smooth and uses far less memory. Detail and Quick Search image panes use the same cached loader.
- **Accessibility** — VoiceOver labels added across menu-bar rows, Quick Search rows, Library cards and rows, and icon-only buttons (pin, favorite, delete, footer actions). Sensitive clips are never read aloud — VoiceOver announces "Hidden sensitive content," mirroring the on-screen redaction.

#### Fixed

- **Capture content-type groups now work** — turning off the **Text** or **Media** group in Settings → Capture previously had no effect; those types kept being captured. The capture pipeline now honors the group master switch.
- **"All groups off" is remembered** — disabling every capture group no longer silently re-enables all of them on the next launch.
- **Crash hardening** — the Accessibility focused-window lookup is now guarded against unexpected system responses (no more force-cast crash), and a database that can't be opened no longer hard-crashes the app at launch.
- **Removed console-log spam** — declared the internal drag-and-drop type in Info.plist, eliminating the repeated `app.quiet.QuietClipboard.item-id … not found` warnings.

---

## [0.2.0] — 2026-06-04

Version **0.2.0**

### Build 1

A correctness, paste-experience, performance, and feature pass.

### Added

- **Restore clipboard after paste** — when you paste a clip from history, your previous clipboard is restored afterward so your working clipboard is left intact (Paste/Raycast-style). Toggle in Settings → General → Paste.
- **Paste as Plain Text** — strips formatting at paste time. Press **⇧↩** in Quick Search, or use the right-click menu on any clip.
- **Accessibility paste guidance** — if automatic paste can't run because Accessibility permission is missing or was revoked, a tappable HUD now guides you to grant it instead of silently doing nothing. The clip is still placed on the clipboard for manual paste.
- **Paste / copy confirmation HUD** — a brief on-screen confirmation after copy and paste. Toggle in Settings → General → Paste.
- **Rich menu bar popover** — the menu bar item now opens a searchable popover with thumbnail rows, per-row pin / favorite / delete, and a quick-action footer (Library, Quick Search, Pause, Settings, Quit), replacing the plain text menu.
- **Quick Look, Reveal in Finder, Open, and Share** — available from the item detail menu and the clip right-click menu. File clips preview the original file; image clips preview a rendered copy.

### Changed

- **Text transforms are now non-destructive** — “Transform” copies the transformed result to the clipboard (captured as a new clip) instead of overwriting the stored clip. The original is preserved.
- **Search covers your whole history** — exact and substring matches are now found across all clips; only the typo-tolerant (fuzzy) pass is bounded to the most recent items for responsiveness. Previously, matches beyond the 800 most-recent clips were silently missed.
- **Faster Library and lists** — the Library’s ranked search result is cached per input, source-app icons are cached instead of resolved per cell on every render, the Library window’s query is torn down while the window is closed, and the menu bar and paste-by-index fetches are bounded.
- **Better content detection** — full-screen screenshots are now tagged as screenshots; URL detection covers `mailto:`, `ftp:`, and bare `www.`; code detection is stricter (fewer plain-text notes misclassified as code); `rgb()` / `hsl()` colors normalize to hex so they deduplicate with the equivalent `#hex`.

### Fixed

- **Corrupt paste of large images** — images are now always written to the pasteboard as valid PNG (plus TIFF for compatibility), re-encoding whatever was stored. This also repairs older items that were stored as JPEG/TIFF but tagged as PNG. Oversized images are downscaled to a usable size rather than reduced to a tiny thumbnail.
- **Copy counts no longer inflate** — pasting a clip from history is correctly recognized as the app’s own pasteboard write and is not re-ingested as a new copy, regardless of representation differences.
- **Paste targets the right app** — paste-by-index (`Ctrl+Cmd+0–9`) and multi-paste no longer paste into Quiet Clipboard’s own Library/Settings window; they target the previously-active app.
- **Sensitive content** — detection no longer skips pastes larger than 200 KB (it scans the start and end); added modern token formats (`sk-proj-`, `gho_`, GitLab, Google); credit-card matching is tighter to reduce false positives on long numeric IDs.
- **Near-duplicate detection** — bounded so a pair of very large clips can no longer allocate an enormous edit-distance matrix; candidate clips are now sorted by recency.
- **Capture reliability** — a watchdog restarts clipboard polling if it ever stalls, so capture can’t silently stop.

---

## [0.1.8] — 2026-06-04

Version **0.1.8**

### Build 1

#### Added

- **Quick Search clear button** — × button appears in the search field whenever text is entered; clears the query in one click
- **Quick Search result count** — a compact "X of Y" label appears below the filter bar whenever a filter or search is active

#### Changed

- **Quick Search bottom bar** — Library, Pause/Resume, Settings, and Quit are now icon-only circle buttons matching the toolbar style; text labels removed
- **Quick Search filter chips** — selected chip now fills with solid accent color and white text instead of a translucent tint; clearer active state at a glance
- **Quick Search filter bar fade** — a gradient mask fades both edges of the filter bar so chips scroll smoothly off-screen without hard clipping
- **Pinned and Favorites chips** — icon-only in the filter bar; tooltip and VoiceOver still expose the full label

#### Fixed

- **Swift 6 concurrency** — `ClipboardMonitor` static size constants (`maxRawBytes`, `maxTextBytes`) marked `nonisolated(unsafe)`; `isTypeCaptured` closure annotated `@Sendable`; resolves actor-isolation errors under Swift 6 language mode

---

## [0.1.7] — 2026-06-04

Version **0.1.7**

### Build 1

#### Added



#### Changed

- **Quick Search open speed** — panel is pre-built at launch and kept alive between opens; subsequent opens are near-instant instead of rebuilding the full SwiftUI hierarchy each time
- **Scroll position** — Quick Search list always resets to top on open so the latest copy is immediately visible
- **Link preview card** — redesigned with card background and border; raw URL moved to a compact bottom strip instead of floating in empty space
- **Text and rich-text thumbnails** — small row thumbnails now render plain text instead of a live NSScrollView (no more scrollbar visible in the 50 pt thumbnail)
- **Color clip display** — label shows the text as originally copied (e.g. `E60EC9` without `#`) rather than always inserting a `#` prefix
- **Settings — Open at / Display** — the Display picker now appears directly below Open at instead of at the bottom of the card
- **Filter bar scrollbar** — horizontal scroller is hidden by default; drag-to-scroll and trackpad scroll still work
- **Color card footer** — hex label no longer overlaps the timestamp / app-icon row

#### Fixed

- **Duplicate clipboard entries** — concurrent ingest tasks for the same content are now serialised via an actor lock; two rapid identical copies no longer create two separate items
- **Color clips creating two entries** — `E60EC9` and `#E60EC9` now normalise to the same content hash so they deduplicate to a single item
- **Quick Search blocked after copy** — pasteboard IPC read (can be 20–100 ms for large images) no longer delays the shortcut handler; a cooperative yield after the read lets the panel appear immediately
- **Redundant pasteboard reads** — TIFF data is skipped when PNG is already present; absent types are never read, reducing unnecessary IPC round-trips

---

## [0.1.7] — 2026-06-04

Version **0.1.7**

### Build 1

#### Added



#### Changed

- **Quick Search open speed** — panel is pre-built at launch and kept alive between opens; subsequent opens are near-instant instead of rebuilding the full SwiftUI hierarchy each time
- **Scroll position** — Quick Search list always resets to top on open so the latest copy is immediately visible
- **Link preview card** — redesigned with card background and border; raw URL moved to a compact bottom strip instead of floating in empty space
- **Text and rich-text thumbnails** — small row thumbnails now render plain text instead of a live NSScrollView (no more scrollbar visible in the 50 pt thumbnail)
- **Color clip display** — label shows the text as originally copied (e.g. `E60EC9` without `#`) rather than always inserting a `#` prefix
- **Settinat / Display** — the Display picker now appears directly below Open at instead of at the bottom of the card
- **Filter bar scrollbar** — horizontal scroller is hidden by default; drag-to-scroll and trackpad scroll still work
- **Color card footer** — hex label no longer overlaps the timestamp / app-icon row

#### Fixed

- **Duplicate clipboard entries** — concurrent ingest tasks for the same content are now serialised via an actor lock; two rapid identical copies no longer create two separate items
- **Color clips creating two entries** — `E60EC9` and `#E60EC9` now normalise to the same content hash so they deduplicate to a single item
- **Quick Search blocked after copy** — pasteboard IPC read (can be 20–100 ms for large images) no longer delays the shortcut handler; a cooperative yield after the read lets the panel appear immediately
- **Redundant pasteboard reads** — TIFF data is skipped when PNG is already present; absent types are never read, reducing unnec-trips

---
## [0.1.5] — 2026-06-03

Version **0.1.5**

### Build 1

#### Added

- **Settings top tab bar** — horizontal tabs (General, Search, Capture, Keys, Stats, Storage, About) replace the sidebar; full cell is clickable with a compact selection pill
- **Settings footer** — capture status, **Library** shortcut, and **Quit** (matches menu bar quit)

#### Changed

- **Settings layout** — inclusive rounded panel for tabs + content; shell/footer spacing aligned with Quiet Reminder–style chrome
- **Settings background** — pure black shell and Library-matched surfaces (`#141414` panels, 6% grouped rows)
- **Settings window** — fixed **540×620** width/height so General opens without a scrollbar; vertically resizable only
- **Settings rows** — colored row icons on General, Capture, Storage, and Shortcuts panels
- **Excluded apps** — balanced chip and button sizing in the grouped card

#### Fixed

- **Tab selection highlight** — no longer stretches full tab-bar height (proper pill around icon + label)
- **Scroll indicators** — `scrollBounceBehavior(.basedOnSize)` hides scroll chrome when content fits

---

## [0.1.4] — 2026-06-03

Version **0.1.4**

### Build 1

#### Added

- **Settings redesign** — sidebar panels (General, Quick Search, Capture, Keyboard Shortcuts, **Statistics**, Storage, About) with Library-matched dark chrome, card layout, and a resizable Settings window (min 620×480)
- **Statistics panel** — storage overview and usage charts (copies/day, top apps, types, busiest hours) moved out of Storage for a clearer split
- **Excluded apps UI** — compact app chips with icons, per-app remove, **Add app** picker, and **Recommended** sheet (password managers, banking, remote desktop)
- **Excluded apps defaults** — first launch seeds only **1Password** and **Keychain Access**; full list stays optional via Recommended
- **Compact settings actions** — `SettingsActionButton` `.compact` size for inline toolbars (excluded-apps row) with readable subheadline labels

#### Changed

- **Storage panel** — retention, manual cleanup, danger zone, and JSON backup/import only (charts live under Statistics)
- **Settings rows** — toggles and pickers align in a fixed trailing control column; action button labels centered
- **Rich clipboard capture** — prefers RTF/HTML/RTFD when plain text is empty; HTML styling without links treated as rich text
- **Pasteboard restore** — archives pasteboard types on copy-back for lossless paste of styled content
- **Previews & paste** — `RichContentRenderer` and `TextClipTransforms` improve display and paste fallbacks for styled clips (e.g. pill/badge UI from browsers)

#### Fixed

- **Blank styled clips** — copying rich UI (styled text, badges, pills) no longer saves or previews as empty content
- **Excluded apps footer** — copy reflects the smaller default set and Recommended flow

---

## [0.1.3] — 2026-06-03

Version **0.1.3**

### Build 1

#### Added

- **Type filter bar** — toolbar button reveals a row of content-type pills (Text, Image, Link, Code, Color, etc.) each with a live count; click any pill to filter the grid; active filter is highlighted; bar hides/shows without disrupting layout
- **App filter bar** — second toolbar button reveals per-source-app pills with app icons and item counts; filter to any single app with one click
- **Responsive filter bars** — all three filter/tab rows (type, app, category) use a wrapping flow layout; when items overflow the window width they wrap to a second row instead of clipping
- **Floating detail panel** — item detail slides in from the right edge over the grid with a spring animation; a semi-transparent scrim dims the grid behind it; panel closes when clicking the scrim or switching tabs
- **Detail panel metadata** — labeled fields for CREATED, SOURCE, LINK, COPIES, LAST COPIED, and SIZE; COPIES and LAST COPIED only appear for items copied more than once; links include an external-link button
- **Detail panel category breadcrumb** — header shows the active tab or category name with a disclosure indicator
- **Inline category creation** — the `+` button in the category tab bar expands an inline text field with a checkmark confirm; no separate sheet required
- **Category rename via popover** — right-click any category pill → Rename opens an inline popover with a pre-filled text field
- **Pause with duration presets** — the menu bar **Pause** menu now offers four preset durations: 10 minutes, 1 hour, 3 hours, or Until tomorrow (resumes at midnight); **Resume** button replaces the Pause menu while paused
- **Auto-resume timer** — monitoring resumes automatically when the chosen pause duration expires
- **Hover actions on grid cards** — hovering a library card reveals a delete button (top-left) and a favorite star (top-right) without opening the detail panel
- **Double-click to copy** — double-clicking a grid card copies the item immediately without opening the detail panel
- **Drag preview** — dragging a card out of the library shows a thumbnail drag preview
- **Drop-target highlighting** — dragging a clip onto the Favorites or Pinned tab pill shows a green ring; dropping assigns the item

#### Changed

- **Library grid tiles** — new `LibraryCard` design with fixed 150 pt height; text clips use a light-grey background; image/media clips use a dark background with a gradient footer for the timestamp and type badge; hover and drag states animate with easing
- **Adaptive grid columns** — grid uses `LazyVGrid` with `.adaptive(minimum: 160, maximum: 240)` columns so the layout responds to window width
- **Filter and category bars no longer scroll horizontally** — replaced `ScrollView(.horizontal)` + `HStack` with a `FlowLayout` that wraps to additional rows as needed
- **Category divider removed** — the fixed divider between built-in tabs and user categories is no longer needed now that the bar wraps naturally
- **Detail panel replaces sidebar** — detail content is now in a floating overlay rather than a fixed sidebar column, giving the grid full width until an item is selected

#### Fixed

- **Horizontal scrollbar artifact** — a visible scrollbar track appeared below the category tab row on macOS 15; fixed by switching from `showsIndicators: false` to `.scrollIndicators(.hidden)`
- **Category tab bar clipping** — long category lists were clipped at the window edge instead of wrapping

---

## [0.1.1] — 2026-06-03

Version **0.1.1**

### Build 1

#### Fixed

- **Rich text link preservation** — copying linked text (e.g. a Jira ticket link, a hyperlinked word in a browser) no longer strips the hyperlink; the app now captures the HTML representation from the clipboard and writes it back on paste, keeping the link intact in apps that accept HTML (browsers, Jira, Notion, etc.)

---

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
