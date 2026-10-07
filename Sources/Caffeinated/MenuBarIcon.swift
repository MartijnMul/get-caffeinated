import AppKit

/// Menu bar icons (Phosphor Icons, MIT): a coffee bean when idle, a cup when awake.
@MainActor
enum MenuBarIcon {
    static let idle = load("coffee-bean", fallbackSymbol: "cup.and.saucer")
    static let awake = load("coffee", fallbackSymbol: "cup.and.saucer.fill")

    /// Loads an SVG from the app bundle as a template image, so macOS tints it
    /// for light mode, dark mode and the highlighted state. Falls back to an SF
    /// Symbol when running outside the bundle (`swift run`).
    private static func load(_ name: String, fallbackSymbol: String) -> NSImage {
        let image = Bundle.main.url(forResource: name, withExtension: "svg").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: "Caffeinated")!
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}
