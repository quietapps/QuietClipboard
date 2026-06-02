<div align="center">

<img src="QuietClipboard/Assets.xcassets/AppIcon.appiconset/icon_1024.png" alt="Quiet Clipboard" width="128" height="128" />

# Quiet Clipboard

**Every copy. Always there. Never in the way.**

A native macOS clipboard history manager that silently captures everything you copy — text, images, links, files, code, colors, screenshots — and keeps it all searchable in a fast, private local library. Part of the [Quiet Apps](https://github.com/quietapps) family.

[![macOS](https://img.shields.io/badge/macOS-15.0+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-SwiftData-2396F3?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/quietapps/QuietClipboard?display_name=tag)](https://github.com/quietapps/QuietClipboard/releases)
[![Downloads](https://img.shields.io/github/downloads/quietapps/QuietClipboard/total.svg)](https://github.com/quietapps/QuietClipboard/releases)
[![Stars](https://img.shields.io/github/stars/quietapps/QuietClipboard?style=social)](https://github.com/quietapps/QuietClipboard/stargazers)

[Install](#install) · [Features](#features) · [Usage](#usage) · [Build from source](#build-from-source) · [FAQ](#faq)

</div>

---

## Why

You copied something twenty minutes ago. You need it now. It's gone.

Quiet Clipboard runs silently in your menu bar and captures every copy you make. Hit `Ctrl+Cmd+V` to open a Spotlight-style search over your entire clipboard history — text, images, links, files, code snippets, hex colors, screenshots — and paste anything back instantly. Everything stays on your machine. No cloud. No account. No telemetry.

## Features

- **Clipboard history** — captures text, rich text, images, screenshots, links, files, code, colors, and SVGs automatically as you copy
- **Quick search overlay** — `Ctrl+Cmd+V` opens a Spotlight-style panel; real-time search across all item content, OCR text, source app, and categories; arrow keys navigate, Enter pastes, Escape dismisses
- **Notch shelf / Dynamic Island panel** — `Ctrl+Cmd+N` slides a floating row of recent clips down from the notch or expands a pill at the top of the screen; drag any clip directly into any app
- **Full library window** — `Ctrl+Cmd+L` opens a grid/list view with sidebar (History, Favorites, Screenshots, custom categories), full-text search, sort by date/type/size/app, multi-select, and Quick Look
- **Menu bar popover** — clipboard icon in your menu bar shows the last 10–15 items with previews, a search field, and quick actions
- **Smart content detection** — identifies URLs, hex colors, code snippets, emails, phone numbers, file paths, and more; badges each item with its type
- **Code highlighting** — syntax-highlighted previews with language detection (Swift, Python, JS, JSON, HTML, CSS, Shell, and more)
- **Color swatches** — parses `#hex`, `rgb()`, `rgba()`, `hsl()`, and named CSS colors; shows a swatch; detail panel copies any format
- **Link previews** — fetches title, description, and preview image for copied URLs via `LPMetadataProvider`; caches results; gracefully falls back to raw URL (toggleable in Settings)
- **OCR on images** — Vision framework extracts text from every captured image and screenshot; OCR text is fully searchable
- **Sensitive content detection** — detects passwords, API keys, private keys, JWTs, credit card numbers, `.env` values, AWS/Stripe/Slack tokens; default behavior is not to save; configurable per your preference
- **Favorites** — star any item; favorites are never auto-deleted by retention rules
- **Custom categories** — create named categories with SF Symbol icons and custom colors; drag items in; items can belong to multiple categories
- **Retention control** — auto-cleanup after 7, 15, 30, or 90 days, or never; favorites exempt; manual clear by type, age, or all at once
- **Keyboard shortcuts** — all six actions are remappable; conflict detection; `Ctrl+Cmd+0–9` pastes the Nth most recent clip directly
- **Paste into prior app** — Quick Search and shortcut paste remember the app that was focused before the panel opened and paste back into it
- **Export / Import** — full history as JSON backup; import restores items with metadata
- **WidgetKit widgets** — Small (3 items), Medium (6 items), and Large (10–12 items) widgets with interactive paste via AppIntents
- **Launch at login** — registers with `SMAppService`; toggle in Settings
- **Pause capture** — suppress capture for a session or indefinitely; menu bar icon shows a paused state
- **Privacy first** — fully offline; zero analytics; zero telemetry; zero accounts; only network call is optional link preview fetching; all data in `~/Library/Application Support/QuietClipboard/`
- **Menu bar agent** — no Dock icon, no app switcher entry

## Install

> **Note:** Quiet Clipboard is not code-signed with an Apple Developer ID. macOS Gatekeeper will warn on first launch. The steps below work around it automatically.

### Homebrew (recommended)

```bash
brew tap quietapps/quietclipboard
brew install --cask quietclipboard
```

The cask strips the macOS quarantine attribute on install so Gatekeeper does not block launch. The tap is at [quietapps/homebrew-quietclipboard](https://github.com/quietapps/homebrew-quietclipboard).

### Direct download

1. Grab `QuietClipboard-1.0.zip` from the [latest release](https://github.com/quietapps/QuietClipboard/releases/latest)
2. Unzip → drag **Quiet Clipboard.app** into `/Applications`
3. Strip the quarantine attribute (or right-click → Open once):

```bash
xattr -cr "/Applications/Quiet Clipboard.app"
```

4. Launch Quiet Clipboard — the clipboard icon appears in your menu bar
5. Click it → the popover opens and capture begins immediately

### If the app doesn't open (Gatekeeper blocked it)

macOS silently blocks unsigned binaries on first launch. Fix it once with any of these:

**Option A — Right-click open (no Terminal needed)**
1. Open Finder → `/Applications`
2. Right-click **Quiet Clipboard.app** → **Open**
3. Click **Open** in the warning dialog
4. macOS remembers your choice for every future launch

**Option B — Terminal**
```bash
xattr -cr "/Applications/Quiet Clipboard.app"
```

**Option C — System Settings**
1. Try to launch the app — macOS shows a blocked notification
2. Open **System Settings → Privacy & Security**
3. Scroll down to the message about Quiet Clipboard
4. Click **Open Anyway**

## Updating

### Homebrew

```bash
brew update
brew upgrade --cask quietclipboard
```

### Direct download

Download the newer zip from [Releases](https://github.com/quietapps/QuietClipboard/releases), drag the new **Quiet Clipboard.app** over the old one in `/Applications`, then run:

```bash
xattr -cr "/Applications/Quiet Clipboard.app"
```

Your clipboard history and settings are stored separately and are unaffected by app updates.

## Uninstalling

### Homebrew

```bash
# Remove the app and its preferences (via the cask's zap stanza)
brew uninstall --cask --zap quietclipboard

# Drop the tap
brew untap quietapps/quietclipboard

# Purge Homebrew's download cache
brew cleanup --prune=all -s
```

Optional manual cleanup if you skipped `--zap`:

```bash
defaults delete app.quiet.QuietClipboard 2>/dev/null
rm -rf ~/Library/Preferences/app.quiet.QuietClipboard.plist \
       "~/Library/Application Support/QuietClipboard" \
       ~/Library/Caches/app.quiet.QuietClipboard \
       ~/Library/HTTPStorages/app.quiet.QuietClipboard \
       ~/Library/Saved\ Application\ State/app.quiet.QuietClipboard.savedState
```

### Direct download

```bash
# Move the app to Trash
rm -rf "/Applications/Quiet Clipboard.app"

# Remove clipboard history + settings
defaults delete app.quiet.QuietClipboard 2>/dev/null
rm -rf ~/Library/Preferences/app.quiet.QuietClipboard.plist \
       "~/Library/Application Support/QuietClipboard" \
       ~/Library/Caches/app.quiet.QuietClipboard \
       ~/Library/HTTPStorages/app.quiet.QuietClipboard \
       ~/Library/Saved\ Application\ State/app.quiet.QuietClipboard.savedState
```

## Usage

| Action | How |
|---|---|
| Open quick search | `Ctrl+Cmd+V` |
| Open notch / island shelf | `Ctrl+Cmd+N` |
| Open full library | `Ctrl+Cmd+L` |
| Paste clip 1–10 directly | `Ctrl+Cmd+0` … `Ctrl+Cmd+9` |
| Open menu bar popover | Click the clipboard icon in the menu bar |
| Pause / resume capture | Click menu bar icon → **Pause capture** |
| Favorite an item | Hover item → click ★, or right-click → **Favorite** |
| Delete an item | Right-click → **Delete** |
| Clear all history | Settings → Storage → **Clear all** (requires confirmation) |
| Export history | Settings → Storage → **Export JSON** |
| Remap a shortcut | Settings → Keyboard Shortcuts → click the shortcut → press new keys |
| Open Settings | Click menu bar icon → **Settings…** |

Quiet Clipboard captures everything automatically once it's running. No further interaction needed.

## Permissions

Quiet Clipboard requires **Accessibility** access to paste back into whichever app was focused when you triggered the quick search overlay or a shortcut paste.

On first use of a paste action, macOS shows its standard privacy prompt. Grant access in **System Settings → Privacy & Security → Accessibility**.

No other permissions are required. The app does not request contacts, location, camera, microphone, or any network entitlements beyond the standard sandbox.

## Keyboard shortcuts

All shortcuts are remappable in **Settings → Keyboard Shortcuts**.

| Action | Default |
|---|---|
| Open Quick Search | `Ctrl+Cmd+V` |
| Open Notch / Island shelf | `Ctrl+Cmd+N` |
| Open Library window | `Ctrl+Cmd+L` |
| Paste clip 1–10 | `Ctrl+Cmd+0` … `Ctrl+Cmd+9` |
| Toggle capture on/off | `Ctrl+Cmd+P` |

## Build from source

### Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later

No paid Apple Developer account required — the project uses ad-hoc signing (`Sign to Run Locally`).

### Steps

```bash
git clone https://github.com/quietapps/QuietClipboard.git
cd QuietClipboard
open QuietClipboard.xcodeproj
```

Press **⌘R** in Xcode. The clipboard icon appears in your menu bar.

Or from the command line:

```bash
xcodebuild -project QuietClipboard.xcodeproj -scheme QuietClipboard -configuration Release build
```

### Project layout

```
QuietClipboard/
├── QuietClipboardApp.swift          # @main, app delegate, menu bar
├── Models/
│   ├── ClipboardItem.swift          # SwiftData model
│   ├── Category.swift               # SwiftData model
│   └── ClipboardContentType.swift   # Enum: text, image, link, code, color…
├── Services/
│   ├── ClipboardMonitor.swift       # Background actor, polls NSPasteboard ~0.5s
│   ├── SensitiveDetector.swift      # On-device secrets detection
│   ├── OCRService.swift             # Vision VNRecognizeTextRequest
│   ├── LinkPreviewService.swift     # LPMetadataProvider + cache
│   ├── ContentTypeDetector.swift    # Heuristic type classification
│   ├── ThumbnailGenerator.swift     # 200px thumbnails per type
│   ├── ShortcutManager.swift        # Global hotkeys, remapping, conflict detection
│   ├── RetentionManager.swift       # Auto-cleanup by age
│   └── ExportImportService.swift    # JSON backup
├── Views/
│   ├── MenuBar/                     # Popover + icon state
│   ├── NotchPanel/                  # Notch shelf + Dynamic Island
│   ├── QuickSearch/                 # Spotlight-style overlay
│   ├── Library/                     # Full window, sidebar, grid, detail
│   ├── Settings/                    # Tabs: General, Capture, Shortcuts, Storage, About
│   └── Shared/                      # Reusable previews: color swatch, code, link card
├── Widgets/                         # WidgetKit: Small, Medium, Large
└── Utilities/                       # Pasteboard helpers, date formatting, color parsing
```

No external dependencies — Apple frameworks only (SwiftUI, SwiftData, Vision, LinkPresentation, WidgetKit, AppIntents).

## Configuration

All settings are in **Settings** (menu bar icon → **Settings…**). Reset to defaults:

```bash
defaults delete app.quiet.QuietClipboard
```

This resets preferences only. Clipboard history stored in `~/Library/Application Support/QuietClipboard/` is unaffected.

## FAQ

**Does Quiet Clipboard send my clipboard data anywhere?**
No. Everything stays on your machine. The only network call the app ever makes is an optional `LPMetadataProvider` request to fetch a preview for copied URLs. You can turn this off in Settings → Capture → Link previews.

**Will it capture my passwords?**
By default, items typed in password fields are marked `org.nspasteboard.ConcealedType` by macOS and are detected as sensitive. The default setting is not to save them. You can change this in Settings → Capture → Sensitive content.

**Why does it need Accessibility permission?**
To paste back into the app that was focused before you opened the quick search overlay. Without it the paste action has no target. The app does not use Accessibility for any other purpose.

**How do I search for a hex color I copied?**
Open quick search (`Ctrl+Cmd+V`) and type the hex value or the word "color". The filter bar also has a Colors filter to show only color items.

**Can I exclude certain apps from being captured?**
Yes — Settings → Capture → Excluded apps. Add any app and copies made while it is frontmost will be ignored.

**How much disk space does the history use?**
Depends on how many images and screenshots you copy. Text-only histories stay small. Check Settings → Storage for a live breakdown and adjust the retention period if needed.

**How do I move history to a new Mac?**
Settings → Storage → **Export JSON** on the old machine. Copy the file to the new Mac. Install Quiet Clipboard, then Settings → Storage → **Import JSON**.

**How do I quit?**
Click the menu bar icon → **Quit**.

## License

[MIT](LICENSE) © Quiet Apps

---

<div align="center">
If Quiet Clipboard saves your work, drop a ⭐ on the repo.
</div>
