import SwiftUI
import AppKit
import Combine

enum Layout {
    static let PW: CGFloat = 200
    static let PH: CGFloat = 280
    static let bottomMargin: CGFloat = 34
    static let displayH: CGFloat = 116
    static let scale: CGFloat = displayH / 72.0
}

final class PetEngine: ObservableObject {

    let objectWillChange = ObservableObjectPublisher()
    weak var panel: NSPanel?
    var onPresentationChange: (() -> Void)?
    var onSchedulingChange: (() -> Void)?
    var model = CatModel()
    var palette = Palettes.orange
    var visible = true
    private(set) var bubbleText: String?
    private(set) var timerText: String?
    private var settings: AppSettings?

    // feet anchor in screen coordinates (AppKit: origin bottom-left, y up)
    private var posX: CGFloat = 0
    private var posY: CGFloat = 0

    // cursor
    private var curX: CGFloat = 0, curY: CGFloat = 0
    private var lastCurX: CGFloat = 0, lastCurY: CGFloat = 0
    private var lastMoveAt = Date()
    private var lastTickAt = Date()
    private var nextMaintenanceAt = Date()
    private var lastPanelOrigin: NSPoint?
    private var lastIgnoresMouseEvents: Bool?
    private var cachedScreens: [NSScreen] = []
    private var cachedDesktopFrame: CGRect?

    // interaction
    private var dragging = false
    private var pullingTail = false
    private var grabDX: CGFloat = 0, grabDY: CGFloat = 0
    private var wasMouseDown = false

    // actions
    private var walkTargetX: CGFloat?
    private var stretchUntil: Date?
    private var scratchUntil: Date?
    private var lastScratchStroke = -1
    private var angryUntil: Date?
    private var reminderTimer: Timer?
    private var scrollUntil: Date?
    private var lastScrollAt: Date?
    private var celebrateUntil: Date?
    private var sadUntil: Date?
    private var activeAgentSessions: [String: Date] = [:]

    // animation accumulators
    private var tailPhase: CGFloat = 0
    private var blink: CGFloat = 0
    private var blinkStart: Date?
    private var nextBlink = Date().addingTimeInterval(2.5)
    private var bounce: CGFloat = 0
    private var squash: CGFloat = 1, squashX: CGFloat = 1
    private var pupX: CGFloat = 0, pupY: CGFloat = 0, lean: CGFloat = 0

    // keyboard reactions
    private var typingUntil: Date?
    private var heat: CGFloat = 0          // 0..1, rises with fast typing
    private var pawTapL: CGFloat = 0, pawTapR: CGFloat = 0
    private var pawSide = false
    private var scrollAmount: CGFloat = 0
    private var scratchPhase: CGFloat = 0

    // pomodoro
    private(set) var pomodoroRunning = false
    private(set) var pomodoroPhase: PomodoroPhase = .focus
    private var pomodoroEndsAt: Date?
    private var pomodoroRemaining: TimeInterval?

    // effects (view space)
    struct Effect { var x: CGFloat; var y: CGFloat; var life: CGFloat; var vy: CGFloat; var vx: CGFloat; var sym: String }
    private var hearts: [Effect] = []
    private var zzz: [Effect] = []
    private var steam: [Effect] = []
    private var scratches: [Effect] = []

    #if DEBUG
    private var debugTickCount = 0
    private var debugRenderCount = 0
    private var debugWindowStart = Date()
    #endif

    // MARK: - setup

    func attach(panel: NSPanel) {
        self.panel = panel
        refreshScreenGeometry()
        if let s = NSScreen.main?.frame {
            posX = s.maxX - 150
            posY = s.minY + 90
        }
        placePanel()
    }

    func refreshScreenGeometry() {
        cachedScreens = NSScreen.screens
        cachedDesktopFrame = cachedScreens.map(\.frame).reduce(nil) { partial, frame in
            partial?.union(frame) ?? frame
        }
        onSchedulingChange?()
    }

    func configure(settings: AppSettings) {
        self.settings = settings
        setSkin(settings.skinName)
        setReminder(minutes: settings.reminderMinutes)
    }

    // MARK: - public actions (from the menu bar)

    func setVisible(_ v: Bool) {
        visible = v
        if v { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
        onSchedulingChange?()
    }

    func callOver() {
        if let s = screen(containing: CGPoint(x: curX, y: curY))?.visibleFrame {
            walkTargetX = min(max(curX, s.minX + 70), s.maxX - 70)
            onSchedulingChange?()
        }
    }

    func triggerStretch() {
        stretchUntil = Date().addingTimeInterval(4.2)
        onSchedulingChange?()
    }

    func triggerScratch() {
        scratchUntil = Date().addingTimeInterval(3.8)
        lastScratchStroke = -1
        onSchedulingChange?()
    }

    /// Called once per key press. We never read *which* key — only that one
    /// happened — so nothing typed is ever inspected, logged, or stored.
    func registerKeystroke() {
        guard visible else { return }
        let now = Date()
        typingUntil = now.addingTimeInterval(0.9)
        heat = min(1, heat + 0.12)
        if pawSide { pawTapL = 1 } else { pawTapR = 1 }
        pawSide.toggle()
        onSchedulingChange?()
    }

    func registerScroll(delta: CGFloat) {
        guard visible else { return }
        let now = Date()
        if let lastScrollAt, now.timeIntervalSince(lastScrollAt) > 1.2 {
            scrollAmount = 0.15
        }
        lastScrollAt = now
        scrollUntil = now.addingTimeInterval(0.7)
        scrollAmount = clampF(scrollAmount + abs(delta) * 0.055, 0.15, 1)
        onSchedulingChange?()
    }

    func handleAgentEvent(source: String, event: String, session: String) {
        let key = "\(source):\(session)"
        let now = Date()
        switch event {
        case "start":
            activeAgentSessions[key] = now
        case "done":
            activeAgentSessions.removeValue(forKey: key)
            celebrateUntil = now.addingTimeInterval(2.2)
        case "failed":
            activeAgentSessions.removeValue(forKey: key)
            sadUntil = now.addingTimeInterval(2.5)
        default:
            break
        }
        onSchedulingChange?()
    }

    func togglePomodoro() {
        if pomodoroRunning {
            if let end = pomodoroEndsAt { pomodoroRemaining = max(1, end.timeIntervalSinceNow) }
            pomodoroEndsAt = nil
            pomodoroRunning = false
        } else {
            let duration = pomodoroRemaining ?? phaseDuration()
            pomodoroEndsAt = Date().addingTimeInterval(duration)
            pomodoroRemaining = nil
            pomodoroRunning = true
        }
        objectWillChange.send()
        onPresentationChange?()
        onSchedulingChange?()
    }

    func resetPomodoro() {
        pomodoroRunning = false
        pomodoroPhase = .focus
        pomodoroEndsAt = nil
        pomodoroRemaining = phaseDuration()
        objectWillChange.send()
        onPresentationChange?()
        onSchedulingChange?()
    }

    var pomodoroMenuTitle: String {
        pomodoroRunning ? "Pause \(pomodoroPhase.rawValue)" : "Start \(pomodoroPhase.rawValue)"
    }

    func setSkin(_ name: String) {
        palette = Palettes.byName(name)
        model.palette = palette
        objectWillChange.send()
        onSchedulingChange?()
    }

    func setReminder(minutes: Int) {
        reminderTimer?.invalidate()
        reminderTimer = nil
        guard minutes > 0 else { return }
        let t = Timer(timeInterval: Double(minutes) * 60.0, repeats: true) { [weak self] _ in
            self?.triggerStretch()
        }
        RunLoop.main.add(t, forMode: .common)
        reminderTimer = t
    }

    var preferredFrameInterval: TimeInterval {
        guard visible else { return .infinity }
        switch model.state {
        case .sleep, .idle:
            return 1.0 / 4.0
        default:
            return 1.0 / 15.0
        }
    }

    // MARK: - adaptive frame step

    func tick() {
        guard visible else { return }
        let now = Date()
        let frameScale = clampF(CGFloat(now.timeIntervalSince(lastTickAt) * 60), 0.25, 8)
        lastTickAt = now
        if now >= nextMaintenanceAt {
            activeAgentSessions = activeAgentSessions.filter { now.timeIntervalSince($0.value) < 30 * 60 }
            nextMaintenanceAt = now.addingTimeInterval(60)
        }
        updatePomodoro(now: now)

        // global cursor
        let loc = NSEvent.mouseLocation
        lastCurX = curX; lastCurY = curY
        curX = loc.x; curY = loc.y
        let moved = hypot(curX - lastCurX, curY - lastCurY)
        if moved > 1.2 { lastMoveAt = now }

        // drag via global button state
        let down = (NSEvent.pressedMouseButtons & 1) != 0
        let over = overCat()
        let overTail = overTail()
        if down && !wasMouseDown && overTail {
            pullingTail = true
            angryUntil = now.addingTimeInterval(2.4)
            walkTargetX = nil
        } else if down && !wasMouseDown && over && !dragging {
            dragging = true
            grabDX = curX - posX
            grabDY = curY - posY
            walkTargetX = nil
        }
        if pullingTail {
            angryUntil = now.addingTimeInterval(2.4)
            if !down { pullingTail = false }
        } else if dragging {
            if down { posX = curX - grabDX; posY = curY - grabDY }
            else { dragging = false }
        }
        wasMouseDown = down

        let state = currentState(now: now)
        model.state = state

        // pupils + head lean toward cursor
        let head = headCenterScreen()
        let dx = curX - posX
        let dy = curY - head.y
        let ang = atan2(Double(dy), Double(dx))
        var tpx = CGFloat(cos(ang)) * 1.2
        var tpy = -CGFloat(sin(ang)) * 1.4   // screen y-up -> view y-down
        if state == .type || state == .overheat || state == .thinking || state == .scroll {
            tpx = 0; tpy = 1.0               // eyes down on the keys
        } else if state == .pet {
            tpx = 0; tpy = 0                 // relax instead of following the cursor
        }
        pupX += (tpx - pupX) * smoothingAlpha(0.2, frameScale: frameScale)
        pupY += (tpy - pupY) * smoothingAlpha(0.2, frameScale: frameScale)
        let tlean = clampF(dx * 0.01, -3, 3)
        lean += (tlean - lean) * smoothingAlpha(0.12, frameScale: frameScale)

        // breathe + tail
        let t = now.timeIntervalSinceReferenceDate
        model.breathe = CGFloat(sin(t / 0.7)) * 0.8
        tailPhase += (state == .angry ? 0.2 : 0.07) * frameScale
        if state == .scratch {
            scratchPhase += 0.11 * frameScale
        } else {
            scratchPhase = 0
        }
        // keyboard cooldown
        heat = max(0, heat - 0.006 * frameScale)
        pawTapL *= pow(0.72, frameScale)
        pawTapR *= pow(0.72, frameScale)

        // blink
        if blinkStart == nil && now > nextBlink {
            blinkStart = now
            nextBlink = now.addingTimeInterval(2.2 + Double.random(in: 0...2.8))
        }
        if let bs = blinkStart {
            let p = now.timeIntervalSince(bs) / 0.16
            blink = p < 1 ? CGFloat(sin(p * Double.pi)) : 0
            if p >= 1 { blinkStart = nil }
        }

        // mochi squash / bounce
        var sq: CGFloat = 1, sqx: CGFloat = 1
        if state == .drag {
            let v = clampF(hypot(curX - lastCurX, curY - lastCurY) * 0.04, 0, 0.55)
            sq = 1 + v; sqx = 1 - v * 0.6
            bounce = 0
        } else if state == .pet {
            bounce = CGFloat(sin(t / 0.14)) * 1.5
        } else if state == .celebrate {
            bounce = abs(CGFloat(sin(t / 0.12))) * 13
        } else {
            bounce = 0
        }
        squash += (sq - squash) * smoothingAlpha(0.25, frameScale: frameScale)
        squashX += (sqx - squashX) * smoothingAlpha(0.25, frameScale: frameScale)

        // walk toward target (call over)
        if let wt = walkTargetX {
            let d = wt - posX
            if abs(d) < 2 { posX = wt; walkTargetX = nil }
            else {
                posX += clampF(d, -2.2 * frameScale, 2.2 * frameScale)
                bounce = abs(CGFloat(sin(t / 0.09))) * 2
            }
        }

        // Allow crossing display boundaries while dragging, then settle on the
        // closest display so the cat cannot be stranded outside the desktop.
        if dragging, let cursorScreen = screen(containing: CGPoint(x: curX, y: curY))?.frame {
            posX = clampF(posX, cursorScreen.minX + 25, cursorScreen.maxX - 25)
            posY = clampF(posY, cursorScreen.minY + 25, cursorScreen.maxY - 25)
        } else if dragging, let desktop = desktopFrame() {
            posX = clampF(posX, desktop.minX + 25, desktop.maxX - 25)
            posY = clampF(posY, desktop.minY + 25, desktop.maxY - 25)
        } else if let s = screen(containing: CGPoint(x: posX, y: posY))?.visibleFrame
                    ?? nearestScreen(to: CGPoint(x: posX, y: posY))?.visibleFrame {
            posX = clampF(posX, s.minX + 40, s.maxX - 40)
            posY = clampF(posY, s.minY + 40, s.maxY - 40)
        }

        stepEffects(state: state, frameScale: frameScale)

        // commit animated values
        model.pupX = pupX; model.pupY = pupY; model.lean = lean
        model.blink = blink; model.tailPhase = tailPhase
        model.squash = squash; model.squashX = squashX; model.bounce = bounce
        model.blush = (state == .pet)
        model.pawTapL = pawTapL; model.pawTapR = pawTapR
        model.heat = heat
        model.scrollAmount = scrollAmount
        model.scratchPhase = scratchPhase
        bubbleText = bubbleText(for: state)
        timerText = pomodoroDisplayText(now: now)
        if pullingTail {
            model.tailPullX = clampF((curX - posX) / Layout.scale, 22, 58)
            model.tailPullY = clampF(BASEYFromCursor(), -22, 24)
        } else {
            model.tailPullX *= pow(0.72, frameScale)
            model.tailPullY *= pow(0.72, frameScale)
        }
        model.palette = palette

        // only capture the mouse while it is over the cat (or being dragged)
        let ignoresMouseEvents = !(over || overTail || dragging || pullingTail)
        if ignoresMouseEvents != lastIgnoresMouseEvents {
            panel?.ignoresMouseEvents = ignoresMouseEvents
            lastIgnoresMouseEvents = ignoresMouseEvents
        }

        placePanelIfNeeded()
        objectWillChange.send()

        #if DEBUG
        recordDebugFrame(now: now)
        #endif
    }

    private func currentState(now: Date) -> PetState {
        if pullingTail { return .tailPull }
        if dragging { return .drag }
        if let cu = celebrateUntil, now < cu { return .celebrate }
        if let sc = scratchUntil, now < sc { return .scratch }
        if let su = stretchUntil, now < su { return .stretch }
        if walkTargetX != nil { return .walk }
        if heat > 0.6 { return .overheat }
        if let tu = typingUntil, now < tu { return .type }
        if !activeAgentSessions.isEmpty { return .thinking }
        if let sc = scrollUntil, now < sc { return .scroll }
        if let sd = sadUntil, now < sd { return .sad }
        if let au = angryUntil, now < au { return .angry }
        let idle = now.timeIntervalSince(lastMoveAt)
        if overCat() { return .pet }
        if idle > (settings?.sleepSeconds ?? 6) { return .sleep }
        return .look
    }

    private func stepEffects(state: PetState, frameScale: CGFloat) {
        let feetViewY = Layout.PH - Layout.bottomMargin
        if state == .pet && Double.random(in: 0...1) < min(1, 0.06 * Double(frameScale)) {
            hearts.append(Effect(x: Layout.PW / 2 + CGFloat.random(in: -14...14),
                                 y: feetViewY - 130, life: 1, vy: 0.6, vx: 0,
                                 sym: Bool.random() ? "\u{2665}" : "\u{266A}"))
        }
        if state == .sleep && Double.random(in: 0...1) < min(1, 0.02 * Double(frameScale)) {
            zzz.append(Effect(x: Layout.PW / 2 + 22, y: feetViewY - 120,
                              life: 1, vy: 0.4, vx: 0.25, sym: "z"))
        }
        if state == .overheat && Double.random(in: 0...1) < min(1, 0.3 * Double(frameScale)) {
            steam.append(Effect(x: Layout.PW / 2 + CGFloat.random(in: -12...16),
                                y: feetViewY - 110, life: 1, vy: 0.8,
                                vx: CGFloat.random(in: -0.2...0.2), sym: ""))
        }
        if state == .scratch {
            let stroke = Int(scratchPhase / .pi)
            if stroke != lastScratchStroke {
                lastScratchStroke = stroke
                for side in [CGFloat(-1), CGFloat(1)] {
                    scratches.append(Effect(x: Layout.PW / 2 + side * 19,
                                            y: feetViewY - 23, life: 1, vy: 0,
                                            vx: side, sym: ""))
                }
            }
        }
        for i in hearts.indices.reversed() {
            hearts[i].y -= hearts[i].vy * frameScale; hearts[i].life -= 0.012 * frameScale
            if hearts[i].life <= 0 { hearts.remove(at: i) }
        }
        for i in zzz.indices.reversed() {
            zzz[i].y -= zzz[i].vy * frameScale
            zzz[i].x += zzz[i].vx * frameScale
            zzz[i].life -= 0.01 * frameScale
            if zzz[i].life <= 0 { zzz.remove(at: i) }
        }
        for i in steam.indices.reversed() {
            steam[i].y -= steam[i].vy * frameScale
            steam[i].x += steam[i].vx * frameScale
            steam[i].life -= 0.025 * frameScale
            if steam[i].life <= 0 { steam.remove(at: i) }
        }
        for i in scratches.indices.reversed() {
            scratches[i].life -= 0.018 * frameScale
            if scratches[i].life <= 0 { scratches.remove(at: i) }
        }
    }

    // MARK: - geometry

    private func headCenterScreen() -> CGPoint {
        CGPoint(x: posX, y: posY + (CatRenderer.BASEY - 29) * Layout.scale)
    }

    private func overCat() -> Bool {
        let halfW = 26 * Layout.scale
        let top = posY + 62 * Layout.scale     // screen y-up: higher = up
        let bottom = posY - 6 * Layout.scale
        return curX >= posX - halfW && curX <= posX + halfW && curY >= bottom && curY <= top
    }

    private func overTail() -> Bool {
        let tailX = posX + 23 * Layout.scale
        let tailY = posY + 26 * Layout.scale
        return hypot(curX - tailX, curY - tailY) < 17 * Layout.scale
    }

    private func BASEYFromCursor() -> CGFloat {
        let cursorSpriteY = CatRenderer.BASEY - (curY - posY) / Layout.scale
        return clampF(cursorSpriteY - 48, -22, 24)
    }

    private func placePanel() {
        let origin = NSPoint(x: posX - Layout.PW / 2, y: posY - Layout.bottomMargin)
        panel?.setFrameOrigin(origin)
        lastPanelOrigin = origin
    }

    private func placePanelIfNeeded() {
        let origin = NSPoint(x: posX - Layout.PW / 2, y: posY - Layout.bottomMargin)
        guard origin != lastPanelOrigin else { return }
        panel?.setFrameOrigin(origin)
        lastPanelOrigin = origin
    }

    private func desktopFrame() -> CGRect? {
        cachedDesktopFrame
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        cachedScreens.first { $0.frame.contains(point) }
    }

    private func nearestScreen(to point: CGPoint) -> NSScreen? {
        cachedScreens.min {
            distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame)
        }
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private func clampF(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, v)) }

    private func smoothingAlpha(_ base: CGFloat, frameScale: CGFloat) -> CGFloat {
        1 - pow(1 - base, frameScale)
    }

    private func phaseDuration() -> TimeInterval {
        let minutes = pomodoroPhase == .focus ? settings?.focusMinutes ?? 25 : settings?.breakMinutes ?? 5
        return TimeInterval(max(1, minutes) * 60)
    }

    private func updatePomodoro(now: Date) {
        guard pomodoroRunning, let end = pomodoroEndsAt, now >= end else { return }
        pomodoroPhase = pomodoroPhase == .focus ? .breakTime : .focus
        pomodoroRunning = settings?.autoStartNext ?? false
        pomodoroEndsAt = pomodoroRunning ? now.addingTimeInterval(phaseDuration()) : nil
        pomodoroRemaining = pomodoroRunning ? nil : phaseDuration()
        if pomodoroPhase == .breakTime {
            celebrateUntil = now.addingTimeInterval(2.2)
            stretchUntil = now.addingTimeInterval(5.2)
        }
        objectWillChange.send()
        onPresentationChange?()
    }

    private func pomodoroDisplayText(now: Date) -> String? {
        guard pomodoroRunning || pomodoroRemaining != nil else { return nil }
        let seconds = max(0, Int((pomodoroEndsAt?.timeIntervalSince(now) ?? pomodoroRemaining ?? 0).rounded(.up)))
        return "\(pomodoroPhase.rawValue) \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func bubbleText(for state: PetState) -> String? {
        let name = settings?.catName ?? "Tekir"
        switch state {
        case .thinking: return "\(name) düşünüyor…"
        case .celebrate: return "\(name): Bitti!"
        case .sad: return "\(name): Olmadı :("
        case .stretch: return "\(name): Biraz esneyelim!"
        case .scratch: return "\(name): Tırmık tırmık!"
        default: return nil
        }
    }

    // MARK: - render (called by the SwiftUI Canvas)

    func render(into context: inout GraphicsContext, size: CGSize) {
        #if DEBUG
        debugRenderCount += 1
        #endif

        CatRenderer.draw(&context, size: size, model: model)

        for h in hearts {
            context.opacity = max(0, Double(h.life))
            let txt = Text(h.sym).font(.system(size: 15)).foregroundColor(Color(hex: "#F2748B"))
            context.draw(txt, at: CGPoint(x: h.x, y: h.y))
        }
        for z in zzz {
            context.opacity = max(0, Double(z.life))
            let sz = 10 + (1 - z.life) * 8
            let txt = Text("z").font(.system(size: Double(sz))).foregroundColor(Color(hex: "#7C8AA0"))
            context.draw(txt, at: CGPoint(x: z.x, y: z.y))
        }
        for s in steam {
            context.opacity = max(0, Double(s.life)) * 0.5
            let r = 3 + (1 - s.life) * 7
            let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
        for scratch in scratches {
            let age = 1 - scratch.life
            let fadeIn = min(1, age / 0.22)
            let fadeOut = min(1, scratch.life / 0.35)
            context.opacity = max(0, Double(fadeIn * fadeOut)) * 0.95
            var marks = Path()
            for offset in [-6.0, -2.0, 2.0, 6.0] {
                marks.move(to: CGPoint(x: scratch.x + offset - scratch.vx * 5, y: scratch.y - 10))
                marks.addQuadCurve(
                    to: CGPoint(x: scratch.x + offset + scratch.vx * 5, y: scratch.y + 10),
                    control: CGPoint(x: scratch.x + offset - scratch.vx * 2, y: scratch.y + 1))
            }
            context.stroke(marks, with: .color(Color(hex: "#7D3E2B")),
                           style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        context.opacity = 1
    }

    #if DEBUG
    private func recordDebugFrame(now: Date) {
        debugTickCount += 1
        let elapsed = now.timeIntervalSince(debugWindowStart)
        guard elapsed >= 1 else { return }
        print("[DeskCat perf] state=\(model.state.rawValue) ticks=\(debugTickCount) renders=\(debugRenderCount)")
        debugTickCount = 0
        debugRenderCount = 0
        debugWindowStart = now
    }
    #endif
}
