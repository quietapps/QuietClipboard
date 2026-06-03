# Publish Quiet Clipboard

Set version first. Run from project root unless a step says `cd`.

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

export VERSION=0.1.6
export BUILD=1
export OLD_VERSION=0.1.5
```

Edit `CHANGELOG.md` and `README.md` (release notes + version strings). Then:

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

sed -i '' "s/MARKETING_VERSION: \"${OLD_VERSION}\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"${BUILD}\"/" project.yml
sed -i '' "s/MARKETING_VERSION = ${OLD_VERSION};/MARKETING_VERSION = ${VERSION};/g" QuietClipboard.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${BUILD};/g" QuietClipboard.xcodeproj/project.pbxproj
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

Edit `.release-notes-${VERSION}.md` or create it, then:

```bash
cd /Users/parth/Projects/Apps/QuietClipboard

git add -A
git status
git commit -m "release: Quiet Clipboard ${VERSION}"
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
cd /Users/parth/Projects/Apps/homebrew-quietclipboard
git pull origin main
```

If tap not cloned yet:

```bash
cd /Users/parth/Projects/Apps
git clone https://github.com/quietapps/homebrew-quietclipboard.git
cd homebrew-quietclipboard
```

```bash
cd /Users/parth/Projects/Apps/homebrew-quietclipboard

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
