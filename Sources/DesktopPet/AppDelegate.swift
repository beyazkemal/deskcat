import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = PetEngine()
    private var panel: PetPanel!
    private var ticker: Timer?

    private var reminderMinutes = 0
    private var skinName = "orange"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // cat panel
        let hosting = NSHostingView(rootView: CatView(engine: engine))
        hosting.frame = NSRect(x: 0, y: 0, width: Layout.PW, height: Layout.PH)
        panel = PetPanel.make(contentView: hosting)
        engine.attach(panel: panel)

        // menu-bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Pet") {
            img.isTemplate = true
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "🐈"
        }
        rebuildMenu()

        // 60fps driver (common mode so it keeps running during menu tracking)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.engine.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "🐈  Pet", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let vis = NSMenuItem(title: engine.visible ? "Hide cat" : "Show cat",
                             action: #selector(toggleVisible), keyEquivalent: "")
        vis.target = self
        menu.addItem(vis)

        let call = NSMenuItem(title: "Call it over", action: #selector(callOver), keyEquivalent: "")
        call.target = self
        menu.addItem(call)

        let stretch = NSMenuItem(title: "Stretch now", action: #selector(stretchNow), keyEquivalent: "")
        stretch.target = self
        menu.addItem(stretch)

        menu.addItem(.separator())

        // reminder submenu
        let reminder = NSMenuItem(title: "Stretch reminder", action: nil, keyEquivalent: "")
        let rsub = NSMenu()
        for (label, value) in [("Off", 0), ("Every 20 min", 20), ("Every 30 min", 30), ("Every 60 min", 60)] {
            let it = NSMenuItem(title: label, action: #selector(pickReminder(_:)), keyEquivalent: "")
            it.target = self
            it.tag = value
            it.state = (reminderMinutes == value) ? .on : .off
            rsub.addItem(it)
        }
        reminder.submenu = rsub
        menu.addItem(reminder)

        // fur color submenu
        let fur = NSMenuItem(title: "Fur color", action: nil, keyEquivalent: "")
        let fsub = NSMenu()
        for (label, name) in [("Orange tabby", "orange"), ("Gray", "gray"), ("Cream", "cream"), ("Tuxedo", "tuxedo")] {
            let it = NSMenuItem(title: label, action: #selector(pickSkin(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = name
            it.state = (skinName == name) ? .on : .off
            fsub.addItem(it)
        }
        fur.submenu = fsub
        menu.addItem(fur)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggleVisible() {
        engine.setVisible(!engine.visible)
        rebuildMenu()
    }
    @objc private func callOver() { engine.callOver() }
    @objc private func stretchNow() { engine.triggerStretch() }
    @objc private func pickReminder(_ sender: NSMenuItem) {
        reminderMinutes = sender.tag
        engine.setReminder(minutes: reminderMinutes)
        rebuildMenu()
    }
    @objc private func pickSkin(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String {
            skinName = name
            engine.setSkin(name)
            rebuildMenu()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
