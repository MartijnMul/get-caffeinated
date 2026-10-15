import AppKit

/// Menu bar icons (Phosphor Icons, MIT): a coffee bean when idle, a cup when awake.
@MainActor
enum MenuBarIcon {
    static let idle = load("coffee-bean", fallbackSymbol: "cup.and.saucer")
    static let awake = load("coffee", fallbackSymbol: "cup.and.saucer.fill")

    private static let size = NSSize(width: 18, height: 18)

    /// Loads an SVG pair from the app bundle as one template image, so macOS
    /// tints it for light mode, dark mode and the highlighted state. It draws
    /// the filled variant on a light menu bar and the outline on a dark one;
    /// the drawing handler runs with the menu bar's appearance, so it follows
    /// mode switches by itself. Falls back to an SF Symbol when running outside
    /// the bundle (`swift run`).
    private static func load(_ name: String, fallbackSymbol: String) -> NSImage {
        guard let outline = svg(name), let filled = svg("\(name)-fill") else {
            let image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: "Get Caffeinated")!
            image.size = size
            image.isTemplate = true
            return image
        }
        let image = NSImage(size: size, flipped: false) { rect in
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            (isDark ? outline : filled).draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func svg(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "svg").flatMap(NSImage.init(contentsOf:))
    }
}
