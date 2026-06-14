import AppKit

// A borderless, transparent, always-on-top panel that never becomes key or
// main, so it never steals focus from whatever you're working in.
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(contentView: NSView) -> PetPanel {
        let panel = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.PW, height: Layout.PH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
        panel.orderFrontRegardless()
        return panel
    }
}
