import CoreGraphics

/// Fixed dimensions for uniform grid tiles (Library + Quick Search popup).
enum LibraryGridMetrics {
    static let tileHeight: CGFloat = 264
    static let previewHeight: CGFloat = 180
    static let footerHeight: CGFloat = 84
    static let popupTileHeight: CGFloat = 130

    // Library grid layout. Single source of truth shared by the grid's `GridItem(.adaptive)`
    // and keyboard navigation, so vertical arrow movement always matches the rendered columns.
    static let libraryTileMinWidth: CGFloat = 160
    static let libraryTileMaxWidth: CGFloat = 240
    static let libraryGridSpacing: CGFloat = 16
    static let libraryGridPadding: CGFloat = 16

    /// Column count `.adaptive(minimum:)` produces for the grid's OWN measured width. Measure
    /// the `LazyVGrid` itself, not the enclosing ScrollView — legacy (space-reserving) scroll
    /// bars shave ~16 pt off the content area, and near a column boundary that difference makes
    /// container-based math over-count by one, sending Up/Down navigation diagonally.
    static func libraryColumnCount(forGridWidth width: CGFloat) -> Int {
        guard width >= libraryTileMinWidth else { return 1 }
        return max(1, Int((width + libraryGridSpacing) / (libraryTileMinWidth + libraryGridSpacing)))
    }
}
