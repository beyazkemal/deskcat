import AppKit
import SwiftUI
import CoreGraphics
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let settings = AppSettings()
    private let hooks = HookInstaller()
    private let engine = PetEngine()
    private var panel: PetPanel!
    private var settingsWindow: NSWindow?
    private var ticker: Timer?
    private var scheduledTickInterval: TimeInterval?
    private var keyEventTap: CFMachPort?
    private var keyEventTapSource: CFRunLoopSource?
    private var keyboardPermissionTimer: Timer?
    private var screenObserver: Any?

    private var settingsObserver: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // cat panel
        let hosting = NSHostingView(rootView: CatView(engine: engine))
        hosting.frame = NSRect(x: 0, y: 0, width: Layout.PW, height: Layout.PH)
        panel = PetPanel.make(contentView: hosting)
        engine.attach(panel: panel)
        engine.configure(settings: settings)
        engine.onPresentationChange = { [weak self] in self?.rebuildMenu() }
        engine.onSchedulingChange = { [weak self] in self?.wakeTicker() }
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.refreshScreenGeometry()
        }

        // menu-bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "DeskCat") {
            img.isTemplate = true
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "🐈"
        }
        rebuildMenu()

        scheduleNextTick(after: 0)

        startKeyboardReactions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    // MARK: - keyboard reactions

    private func startKeyboardReactions() {
        stopKeyboardReactions()

        guard CGPreflightListenEventAccess() else {
            watchForKeyboardPermission()
            rebuildMenu()
            return
        }

        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    DispatchQueue.main.async {
                        appDelegate.startKeyboardReactions()
                    }
                } else if type == .keyDown {
                    DispatchQueue.main.async {
                        appDelegate.engine.registerKeystroke()
                    }
                } else if type == .scrollWheel {
                    let delta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
                    DispatchQueue.main.async {
                        appDelegate.engine.registerScroll(delta: CGFloat(delta))
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            watchForKeyboardPermission()
            rebuildMenu()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        keyEventTap = tap
        keyEventTapSource = source
        rebuildMenu()
    }

    private func stopKeyboardReactions() {
        if let source = keyEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = keyEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        keyEventTapSource = nil
        keyEventTap = nil
    }

    private func watchForKeyboardPermission() {
        guard keyboardPermissionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard CGPreflightListenEventAccess() else { return }
            timer.invalidate()
            self?.keyboardPermissionTimer = nil
            self?.startKeyboardReactions()
        }
        RunLoop.main.add(timer, forMode: .common)
        keyboardPermissionTimer = timer
    }

    @objc private func enableKeyboard() {
        if CGPreflightListenEventAccess() {
            startKeyboardReactions()
            return
        }

        _ = CGRequestListenEventAccess()
        if CGPreflightListenEventAccess() {
            startKeyboardReactions()
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
            watchForKeyboardPermission()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - adaptive animation driver

    private func scheduleNextTick(after interval: TimeInterval) {
        ticker?.invalidate()
        ticker = nil
        scheduledTickInterval = nil
        guard engine.visible else { return }

        let timer = Timer(timeInterval: max(0.001, interval), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.ticker = nil
            self.scheduledTickInterval = nil
            self.engine.tick()
            self.scheduleNextTick(after: self.engine.preferredFrameInterval)
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        scheduledTickInterval = interval
    }

    private func wakeTicker() {
        guard engine.visible else {
            ticker?.invalidate()
            ticker = nil
            scheduledTickInterval = nil
            return
        }
        // Wake immediately from the 4 FPS sleep cadence, but do not let a
        // burst of key/scroll events bypass the active 15 FPS frame cap.
        guard ticker == nil || (scheduledTickInterval ?? 1) > 1.0 / 12.0 else { return }
        scheduleNextTick(after: 0)
    }

    // MARK: - menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "🐈  \(settings.catName)", action: nil, keyEquivalent: "")
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
        let scratch = NSMenuItem(title: "Scratch now", action: #selector(scratchNow), keyEquivalent: "")
        scratch.target = self
        menu.addItem(scratch)

        menu.addItem(.separator())

        let pomodoro = NSMenuItem(title: engine.pomodoroMenuTitle, action: #selector(togglePomodoro), keyEquivalent: "")
        pomodoro.target = self
        menu.addItem(pomodoro)
        let resetPomodoro = NSMenuItem(title: "Reset Pomodoro", action: #selector(resetPomodoro), keyEquivalent: "")
        resetPomodoro.target = self
        menu.addItem(resetPomodoro)

        menu.addItem(.separator())
        let keyboardTitle: String
        if !CGPreflightListenEventAccess() {
            keyboardTitle = "Keyboard reactions: permission required…"
        } else if keyEventTap == nil {
            keyboardTitle = "Keyboard reactions: listener unavailable"
        } else {
            keyboardTitle = "Keyboard reactions: enabled"
        }
        let kb = NSMenuItem(title: keyboardTitle, action: #selector(enableKeyboard), keyEquivalent: "")
        kb.target = self
        kb.state = keyEventTap == nil ? .off : .on
        menu.addItem(kb)

        let testKeyboard = NSMenuItem(title: "Test keyboard animation", action: #selector(testKeyboardAnimation), keyEquivalent: "")
        testKeyboard.target = self
        menu.addItem(testKeyboard)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
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
    @objc private func scratchNow() { engine.triggerScratch() }
    @objc private func togglePomodoro() {
        engine.togglePomodoro()
        rebuildMenu()
    }
    @objc private func resetPomodoro() {
        engine.resetPomodoro()
        rebuildMenu()
    }
    @objc private func testKeyboardAnimation() {
        for index in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.09) { [weak self] in
                self?.engine.registerKeystroke()
            }
        }
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings, hooks: hooks, engine: engine))
            let window = NSWindow(contentViewController: hosting)
            window.title = "DeskCat"
            window.subtitle = "Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let components = URLComponents(string: text) else { return }
        if components.host == "settings" {
            showSettings()
            return
        }
        guard components.host == "agent" else { return }
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
            item in item.value.map { (item.name, $0) }
        })
        engine.handleAgentEvent(source: values["source"] ?? "agent",
                                event: values["event"] ?? "",
                                session: values["session"] ?? "default")
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
