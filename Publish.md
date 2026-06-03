# Publish Quiet Clipboard

End-to-end checklist to ship a new version: bump version → build → zip → GitHub release → Homebrew cask → users can upgrade.

Replace `0.1.6` below with the version you are shipping.

---

## Prerequisites

- macOS 15+ with Xcode 16+
- [`gh`](https://cli.github.com/) installed and authenticated (`gh auth status`)
- Git write access to:
  - `quietapps/QuietClipboard`
  - `quietapps/homebrew-quietclipboard`
- Clean working tree on `main` (commit or stash unrelated work first)

```bash
export VERSION=0.1.6          # new marketing version (tag name)
export BUILD=1                  # CFBundleVersion / CURRENT_PROJECT_VERSION
export REPO_ROOT="$(pwd)"       # run from QuietClipboard repo root
```

---

## 1. Bump version in the project

Version lives in three places. Keep them aligned.

### `project.yml`

```yaml
MARKETING_VERSION: "0.1.6"
CURRENT_PROJECT_VERSION: "1"   # reset to 1 for a new marketing version; increment for same-version rebuild
```

### `QuietClipboard.xcodeproj/project.pbxproj`

Update **both** QuietClipboard target configs (Debug + Release):

```
MARKETING_VERSION = 0.1.6;
CURRENT_PROJECT_VERSION = 1;
```

Search the file for the old version and replace only the app-target entries (ignore stale values in unrelated build configs if any).

### `README.md`

Update version mentions:

- Features section: `**Current release (Xcode):** version **0.1.6**, build **1**`
- Direct download line: `currently **0.1.6**`

`QuietClipboard/Info.plist` uses `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` — no manual edit needed there.

---

## 2. Update changelog

Add a new section at the top of `CHANGELOG.md`:

```markdown
## [0.1.6] — YYYY-MM-DD

Version **0.1.6**

### Build 1

#### Added
- …

#### Changed
- …

#### Fixed
- …

---
```

Follow [Keep a Changelog](https://keepachangelog.com/) categories used in prior releases.

---

## 3. Build Release

From repo root:

```bash
cd "$REPO_ROOT"

xcodebuild \
  -project QuietClipboard.xcodeproj \
  -scheme QuietClipboard \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  clean build
```

Built app path:

```bash
APP="build/DerivedData/Build/Products/Release/Quiet Clipboard.app"
```

Sanity checks:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
```

Expected: `0.1.6` and `1` (or whatever you set).

Optional: run the app from DerivedData and smoke-test before zipping.

---

## 4. Create the release zip

Zip name must match GitHub asset + Homebrew cask: `QuietClipboard-<version>.zip`

```bash
cd build/DerivedData/Build/Products/Release

# Avoid __MACOSX junk in the archive
COPYFILE_DISABLE=1 zip -r "$REPO_ROOT/QuietClipboard-${VERSION}.zip" "Quiet Clipboard.app"
```

Compute SHA-256 (needed for Homebrew):

```bash
shasum -a 256 "$REPO_ROOT/QuietClipboard-${VERSION}.zip"
```

Save the hash — you will paste it into the cask.

**Do not commit the zip to the QuietClipboard repo.** Upload it only as a GitHub release asset.

---

## 5. Write GitHub release notes

Create a short notes file (optional local draft):

```bash
cat > "$REPO_ROOT/.release-notes-${VERSION}.md" <<EOF
One-line summary of the release.

### Added
- …

### Changed
- …

### Fixed
- …

Full notes: [CHANGELOG.md](https://github.com/quietapps/QuietClipboard/blob/${VERSION}/CHANGELOG.md#016--YYYY-MM-DD)
EOF
```

Adjust the CHANGELOG anchor slug to match your new heading.

---

## 6. Commit, tag, and push (QuietClipboard)

Stage release metadata and source changes (not the zip):

```bash
cd "$REPO_ROOT"

git add CHANGELOG.md README.md project.yml QuietClipboard.xcodeproj/project.pbxproj
# add any feature/fix files for this release
git status

git commit -m "$(cat <<EOF
release: Quiet Clipboard ${VERSION}

Short summary of what users get in this release.
EOF
)"

git tag "${VERSION}"
git push origin main
git push origin "${VERSION}"
```

---

## 7. Create the GitHub release

Upload the zip asset and publish:

```bash
gh release create "${VERSION}" \
  "$REPO_ROOT/QuietClipboard-${VERSION}.zip" \
  --repo quietapps/QuietClipboard \
  --title "Quiet Clipboard ${VERSION}" \
  --notes-file "$REPO_ROOT/.release-notes-${VERSION}.md"
```

Verify:

```bash
gh release view "${VERSION}" --repo quietapps/QuietClipboard
open "https://github.com/quietapps/QuietClipboard/releases/tag/${VERSION}"
```

Direct-download URL (what Homebrew uses):

```
https://github.com/quietapps/QuietClipboard/releases/download/${VERSION}/QuietClipboard-${VERSION}.zip
```

---

## 8. Update Homebrew cask

Tap repo: [quietapps/homebrew-quietclipboard](https://github.com/quietapps/homebrew-quietclipboard)

### Clone or update the tap

```bash
# first time
git clone https://github.com/quietapps/homebrew-quietclipboard.git ~/Projects/Apps/homebrew-quietclipboard

cd ~/Projects/Apps/homebrew-quietclipboard
git checkout main
git pull origin main
```

### Edit `Casks/quietclipboard.rb`

Update **only** these two lines (rest stays the same):

```ruby
version "0.1.6"
sha256 "PASTE_SHA256_FROM_STEP_4"
```

The `url` stanza already interpolates `#{version}` — no change needed unless the asset name changes.

### Commit and push

```bash
cd ~/Projects/Apps/homebrew-quietclipboard

git add Casks/quietclipboard.rb
git commit -m "quietclipboard ${VERSION}"
git push origin main
```

---

## 9. Verify installs

### Homebrew (fresh install)

```bash
brew update
brew upgrade --cask quietclipboard
# or first-time:
# brew tap quietapps/quietclipboard
# brew install --cask quietclipboard
```

### Homebrew (confirm version)

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "/Applications/Quiet Clipboard.app/Contents/Info.plist"
```

### Direct download

Download the zip from the release page, drag to `/Applications`, then:

```bash
xattr -cr "/Applications/Quiet Clipboard.app"
```

---

## 10. Tell users to upgrade

Homebrew users:

```bash
brew update && brew upgrade --cask quietclipboard
```

Direct-download users: grab the new zip from [Releases](https://github.com/quietapps/QuietClipboard/releases/latest), replace the app in `/Applications`, run `xattr -cr` if Gatekeeper blocks launch.

Clipboard history and settings are stored outside the app bundle and survive upgrades.

---

## Quick reference

| Item | Value |
|---|---|
| App bundle name | `Quiet Clipboard.app` |
| Bundle ID | `app.quiet.QuietClipboard` |
| Zip asset name | `QuietClipboard-<version>.zip` |
| Git tag | `<version>` (e.g. `0.1.6`) |
| GitHub repo | `quietapps/QuietClipboard` |
| Homebrew tap | `quietapps/quietclipboard` |
| Cask name | `quietclipboard` |
| Min macOS | 15.0 (Sequoia) |

---

## Same-version rebuild (hotfix zip only)

If you need a new build **without** bumping the marketing version:

1. Increment `CURRENT_PROJECT_VERSION` / `BUILD` (e.g. `1` → `2`)
2. Add `### Build 2` under the existing CHANGELOG version section
3. Rebuild, re-zip, **replace** the GitHub release asset (or delete + re-upload)
4. Update Homebrew `sha256` only (version string unchanged)

Homebrew users must run `brew upgrade --cask quietclipboard` again after the cask SHA changes.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Gatekeeper blocks launch | `xattr -cr "/Applications/Quiet Clipboard.app"` or right-click → Open once |
| `brew upgrade` says up to date | `brew update` first; confirm cask commit landed on `main` |
| Homebrew SHA mismatch | Re-run `shasum -a 256` on the exact zip uploaded to GitHub |
| Zip contains `__MACOSX/` | Recreate with `COPYFILE_DISABLE=1 zip -r …` |
| About shows wrong version | Re-check `MARKETING_VERSION` in pbxproj Release config and rebuild |
