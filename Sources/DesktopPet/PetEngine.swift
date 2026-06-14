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

    weak var panel: NSPanel?
    var model = CatModel()
    var palette = Palettes.orange
    var visible = true

    // feet anchor in screen coordinates (AppKit: origin bottom-left, y up)
    private var posX: CGFloat = 0
    private var posY: CGFloat = 0

    // cursor
    private var curX: CGFloat = 0, curY: CGFloat = 0
    private var lastCurX: CGFloat = 0, lastCurY: CGFloat = 0
    private var speed: CGFloat = 0
    private var lastMoveAt = Date()

    // interaction
    private var dragging = false
    private var grabDX: CGFloat = 0, grabDY: CGFloat = 0
    private var wasMouseDown = false

    // actions
    private var walkTargetX: CGFloat?
    private var stretchUntil: Date?
    private var reminderTimer: Timer?

    // animation accumulators
    private var tailPhase: CGFloat = 0
    private var blink: CGFloat = 0
    private var blinkStart: Date?
    private var nextBlink = Date().addingTimeInterval(2.5)
    private var pounceUntil: Date?
    private var pounceVX: CGFloat = 0
    private var bounce: CGFloat = 0
    private var squash: CGFloat = 1, squashX: CGFloat = 1
    private var pupX: CGFloat = 0, pupY: CGFloat = 0, lean: CGFloat = 0

    // keyboard reactions
    private var typingUntil: Date?
    private var heat: CGFloat = 0          // 0..1, rises with fast typing
    private var pawTapL: CGFloat = 0, pawTapR: CGFloat = 0
    private var pawSide = false

    // effects (view space)
    struct Effect { var x: CGFloat; var y: CGFloat; var life: CGFloat; var vy: CGFloat; var vx: CGFloat; var sym: String }
    private var hearts: [Effect] = []
    private var zzz: [Effect] = []
    private var steam: [Effect] = []

    // MARK: - setup

    func attach(panel: NSPanel) {
        self.panel = panel
        if let s = NSScreen.main?.frame {
            posX = s.maxX - 150
            posY = s.minY + 90
        }
        placePanel()
    }

    // MARK: - public actions (from the menu bar)

    func setVisible(_ v: Bool) {
        visible = v
        if v { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
    }

    func callOver() {
        if let s = NSScreen.main?.frame {
            walkTargetX = min(max(curX, s.minX + 70), s.maxX - 70)
        }
    }

    func triggerStretch() { stretchUntil = Date().addingTimeInterval(4.2) }

    /// Called once per key press. We never read *which* key — only that one
    /// happened — so nothing typed is ever inspected, logged, or stored.
    func registerKeystroke() {
        guard visible else { return }
        let now = Date()
        typingUntil = now.addingTimeInterval(0.9)
        heat = min(1, heat + 0.12)
        if pawSide { pawTapL = 1 } else { pawTapR = 1 }
        pawSide.toggle()
    }

    func setSkin(_ name: String) { palette = Palettes.byName(name) }

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

    // MARK: - per-frame step (~60fps)

    func tick() {
        guard visible else { return }
        let now = Date()

        // global cursor
        let loc = NSEvent.mouseLocation
        lastCurX = curX; lastCurY = curY
        curX = loc.x; curY = loc.y
        let moved = hypot(curX - lastCurX, curY - lastCurY)
        speed = speed * 0.6 + moved * 0.4
        if moved > 1.2 { lastMoveAt = now }

        // drag via global button state
        let down = (NSEvent.pressedMouseButtons & 1) != 0
        let over = overCat()
        if down && !wasMouseDown && over && !dragging {
            dragging = true
            grabDX = curX - posX
            grabDY = curY - posY
            walkTargetX = nil
        }
        if dragging {
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
        if state == "type" || state == "overheat" {
            tpx = 0; tpy = 1.0               // eyes down on the keys
        }
        pupX += (tpx - pupX) * 0.2
        pupY += (tpy - pupY) * 0.2
        let tlean = clampF(dx * 0.01, -3, 3)
        lean += (tlean - lean) * 0.12

        // breathe + tail
        let t = now.timeIntervalSinceReferenceDate
        model.breathe = CGFloat(sin(t / 0.7)) * 0.8
        tailPhase += (state == "hunt" ? 0.2 : 0.07)

        // keyboard cooldown
        heat = max(0, heat - 0.006)
        pawTapL *= 0.72
        pawTapR *= 0.72

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
        if state == "drag" {
            let v = clampF(hypot(curX - lastCurX, curY - lastCurY) * 0.04, 0, 0.55)
            sq = 1 + v; sqx = 1 - v * 0.6
            bounce = 0
        } else if state == "pet" {
            bounce = CGFloat(sin(t / 0.14)) * 1.5
        } else {
            bounce = 0
        }
        squash += (sq - squash) * 0.25
        squashX += (sqx - squashX) * 0.25

        // pounce while hunting
        if state == "hunt" {
            if (pounceUntil == nil || now > pounceUntil!) && Double.random(in: 0...1) < 0.03 {
                pounceUntil = now.addingTimeInterval(0.24)
                pounceVX = clampF(dx, -60, 60) * 0.08
            }
        }
        if let pu = pounceUntil, now < pu { posX += pounceVX }

        // walk toward target (call over)
        if let wt = walkTargetX {
            let d = wt - posX
            if abs(d) < 2 { posX = wt; walkTargetX = nil }
            else { posX += clampF(d, -2.2, 2.2); bounce = abs(CGFloat(sin(t / 0.09))) * 2 }
        }

        // keep on screen
        if let s = NSScreen.main?.frame {
            posX = clampF(posX, s.minX + 40, s.maxX - 40)
            posY = clampF(posY, s.minY + 40, s.maxY - 40)
        }

        stepEffects(state: state)

        // commit animated values
        model.pupX = pupX; model.pupY = pupY; model.lean = lean
        model.blink = blink; model.tailPhase = tailPhase
        model.squash = squash; model.squashX = squashX; model.bounce = bounce
        model.blush = (state == "pet")
        model.pawTapL = pawTapL; model.pawTapR = pawTapR
        model.heat = heat
        model.palette = palette

        // only capture the mouse while it is over the cat (or being dragged)
        panel?.ignoresMouseEvents = !(over || dragging)

        placePanel()
        objectWillChange.send()
    }

    private func currentState(now: Date) -> String {
        if dragging { return "drag" }
        if let su = stretchUntil, now < su { return "stretch" }
        if walkTargetX != nil { return "walk" }
        if heat > 0.6 { return "overheat" }
        if let tu = typingUntil, now < tu { return "type" }
        let head = headCenterScreen()
        let dx = curX - posX
        let dy = curY - head.y
        let dist = hypot(dx, dy)
        let idle = now.timeIntervalSince(lastMoveAt)
        if dist < 46 && speed < 1.6 { return "pet" }
        if speed > 8 && dist < 460 { return "hunt" }
        if idle > 7 { return "sleep" }
        return "look"
    }

    private func stepEffects(state: String) {
        let feetViewY = Layout.PH - Layout.bottomMargin
        if state == "pet" && Double.random(in: 0...1) < 0.06 {
            hearts.append(Effect(x: Layout.PW / 2 + CGFloat.random(in: -14...14),
                                 y: feetViewY - 130, life: 1, vy: 0.6, vx: 0,
                                 sym: Bool.random() ? "\u{2665}" : "\u{266A}"))
        }
        if state == "sleep" && Double.random(in: 0...1) < 0.02 {
            zzz.append(Effect(x: Layout.PW / 2 + 22, y: feetViewY - 120,
                              life: 1, vy: 0.4, vx: 0.25, sym: "z"))
        }
        if state == "overheat" && Double.random(in: 0...1) < 0.3 {
            steam.append(Effect(x: Layout.PW / 2 + CGFloat.random(in: -12...16),
                                y: feetViewY - 110, life: 1, vy: 0.8,
                                vx: CGFloat.random(in: -0.2...0.2), sym: ""))
        }
        for i in hearts.indices.reversed() {
            hearts[i].y -= hearts[i].vy; hearts[i].life -= 0.012
            if hearts[i].life <= 0 { hearts.remove(at: i) }
        }
        for i in zzz.indices.reversed() {
            zzz[i].y -= zzz[i].vy; zzz[i].x += zzz[i].vx; zzz[i].life -= 0.01
            if zzz[i].life <= 0 { zzz.remove(at: i) }
        }
        for i in steam.indices.reversed() {
            steam[i].y -= steam[i].vy; steam[i].x += steam[i].vx; steam[i].life -= 0.025
            if steam[i].life <= 0 { steam.remove(at: i) }
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

    private func placePanel() {
        panel?.setFrameOrigin(NSPoint(x: posX - Layout.PW / 2, y: posY - Layout.bottomMargin))
    }

    private func clampF(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, v)) }

    // MARK: - render (called by the SwiftUI Canvas)

    func render(into context: inout GraphicsContext, size: CGSize) {
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
        context.opacity = 1

        if model.state == "stretch" { drawBubble(&context, text: "stretch~ \u{1F64C}") }
    }

    private func drawBubble(_ c: inout GraphicsContext, text: String) {
        let styled = Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#4A3320"))
        let resolved = c.resolve(styled)
        let ts = resolved.measure(in: CGSize(width: 240, height: 60))
        let pad: CGFloat = 8
        let bw = ts.width + pad * 2
        let bh: CGFloat = 22
        let cx = Layout.PW / 2
        let feetY = Layout.PH - Layout.bottomMargin
        let by = feetY - Layout.displayH - bh - 6
        let rect = CGRect(x: cx - bw / 2, y: by, width: bw, height: bh)
        let path = Path(roundedRect: rect, cornerRadius: 7)
        c.fill(path, with: .color(Color.white.opacity(0.96)))
        c.stroke(path, with: .color(Color(hex: "#6B4423")), lineWidth: 1.5)
        var tailP = Path()
        tailP.move(to: CGPoint(x: cx - 4, y: by + bh - 1))
        tailP.addLine(to: CGPoint(x: cx + 4, y: by + bh - 1))
        tailP.addLine(to: CGPoint(x: cx, y: by + bh + 6))
        tailP.closeSubpath()
        c.fill(tailP, with: .color(Color.white.opacity(0.96)))
        c.draw(resolved, at: CGPoint(x: cx, y: by + bh / 2))
    }
}
