# Publish Quiet Clipboard

## 1. Edit below only

Change this block each release. Then run section 2 top to bottom in the same terminal.

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

export VERSION=0.1.8
export BUILD=1
export OLD_VERSION=0.1.7
export RELEASE_DATE=$(date +%Y-%m-%d)
export CHANGELOG_ANCHOR="$(echo "$VERSION" | tr -d '.')--${RELEASE_DATE}"

export RELEASE_SUMMARY="Quick Search gets a clear button, result count, icon-only bottom bar, and solid accent chip highlights; Swift 6 concurrency warnings resolved."

export RELEASE_ADDED="$(cat <<'EOF'
- **Quick Search clear button** — × button appears in the search field whenever text is entered; clears the query in one click
- **Quick Search result count** — a compact "X of Y" label appears below the filter bar whenever a filter or search is active
EOF
)"

export RELEASE_CHANGED="$(cat <<'EOF'
- **Quick Search bottom bar** — Library, Pause/Resume, Settings, and Quit are now icon-only circle buttons matching the toolbar style; text labels removed
- **Quick Search filter chips** — selected chip now fills with solid accent color and white text instead of a translucent tint; clearer active state at a glance
- **Quick Search filter bar fade** — a gradient mask fades both edges of the filter bar so chips scroll smoothly off-screen without hard clipping
- **Pinned and Favorites chips** — icon-only in the filter bar; tooltip and VoiceOver still expose the full label
EOF
)"

export RELEASE_FIXED="$(cat <<'EOF'
- **Swift 6 concurrency** — `ClipboardMonitor` static size constants (`maxRawBytes`, `maxTextBytes`) marked `nonisolated(unsafe)`; `isTypeCaptured` closure annotated `@Sendable`; resolves actor-isolation errors under Swift 6 language mode
EOF
)"
```

---

## 2. Run below as-is

Do not edit. Run each block in order after section 1.

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

sed -i '' "s/MARKETING_VERSION: \"${OLD_VERSION}\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"${BUILD}\"/" project.yml
sed -i '' "s/MARKETING_VERSION = ${OLD_VERSION};/MARKETING_VERSION = ${VERSION};/g" QuietClipboard.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${BUILD};/g" QuietClipboard.xcodeproj/project.pbxproj
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

sed -i '' "s/version \*\*${OLD_VERSION}\*\*, build \*\*[0-9]*\*\*/version **${VERSION}**, build **${BUILD}**/" README.md
sed -i '' "s/currently \*\*${OLD_VERSION}\*\*/currently **${VERSION}**/" README.md
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

{
  head -n 8 CHANGELOG.md
  cat <<EOF

## [${VERSION}] — ${RELEASE_DATE}

Version **${VERSION}**

### Build ${BUILD}

#### Added

${RELEASE_ADDED}

#### Changed

${RELEASE_CHANGED}

#### Fixed

${RELEASE_FIXED}

---
EOF
  tail -n +9 CHANGELOG.md
} > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

cat > ".release-notes-${VERSION}.md" <<EOF
${RELEASE_SUMMARY}

### Added

${RELEASE_ADDED}

### Changed

${RELEASE_CHANGED}

### Fixed

${RELEASE_FIXED}

Full notes: [CHANGELOG.md](https://github.com/quietapps/QuietClipboard/blob/${VERSION}/CHANGELOG.md#${CHANGELOG_ANCHOR})
EOF
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

xcodebuild \
  -project QuietClipboard.xcodeproj \
  -scheme QuietClipboard \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  clean build
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard/build/DerivedData/Build/Products/Release

COPYFILE_DISABLE=1 zip -r "/Users/parth/Projects/Apps/QuietClipboard/QuietClipboard-${VERSION}.zip" "Quiet Clipboard.app"
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

export SHA256=$(shasum -a 256 "QuietClipboard-${VERSION}.zip" | awk '{print $1}')
echo "$SHA256"
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "build/DerivedData/Build/Products/Release/Quiet Clipboard.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "build/DerivedData/Build/Products/Release/Quiet Clipboard.app/Contents/Info.plist"
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

git add CHANGELOG.md README.md project.yml QuietClipboard.xcodeproj/project.pbxproj
git add QuietClipboard/
git status
git commit -m "$(cat <<EOF
release: Quiet Clipboard ${VERSION}

${RELEASE_SUMMARY}
EOF
)"
git tag "${VERSION}"
git push origin main
git push origin "${VERSION}"
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

gh release create "${VERSION}" \
  "QuietClipboard-${VERSION}.zip" \
  --repo quietapps/QuietClipboard \
  --title "Quiet Clipboard ${VERSION}" \
  --notes-file ".release-notes-${VERSION}.md"
```

```bash
cd /Users/parth/Projects/Apps/HomeBrew/homebrew-quietclipboard
git pull origin main
```

```bash
cd /Users/parth/Projects/Apps/HomeBrew/homebrew-quietclipboard

sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/quietclipboard.rb
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Casks/quietclipboard.rb
git diff Casks/quietclipboard.rb
git add Casks/quietclipboard.rb
git commit -m "quietclipboard ${VERSION}"
git push origin main
```

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

brew update
brew upgrade --cask quietclipboard
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "/Applications/Quiet Clipboard.app/Contents/Info.plist"
```
