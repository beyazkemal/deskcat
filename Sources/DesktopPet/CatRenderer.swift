import SwiftUI

// Draws the cat into a SwiftUI GraphicsContext. The cat is laid out in a 64x72
// "sprite" coordinate space (origin top-left, y down — same as GraphicsContext),
// then scaled up and anchored at its feet. Direct port of the canvas renderer.
enum CatRenderer {

    static let OFFW: CGFloat = 64
    static let OFFH: CGFloat = 72
    static let BASEY: CGFloat = 66   // feet line
    static let CX: CGFloat = 32      // horizontal centre

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, model m: CatModel) {
        var c = ctx
        let feetX = size.width / 2
        let feetY = size.height - Layout.bottomMargin
        c.translateBy(x: feetX, y: feetY - m.bounce)
        c.scaleBy(x: Layout.scale * m.squashX, y: Layout.scale * m.squash)
        c.translateBy(x: -CX, y: -BASEY)
        drawSprite(&c, m)
    }

    // MARK: - sprite

    private static func drawSprite(_ c: inout GraphicsContext, _ m: CatModel) {
        let P = m.palette

        var pose = "sit"
        var eye = "open"
        switch m.state {
        case "hunt": pose = "crouch"; eye = "wide"
        case "pet": eye = "happy"
        case "sleep": pose = "sleep"; eye = "sleep"
        case "drag": eye = "dizzy"
        case "stretch": pose = "stretch"; eye = "happy"
        default: pose = "sit"; eye = "open"
        }

        let breathe = m.breathe
        var bodyCY: CGFloat, bodyRX: CGFloat, bodyRY: CGFloat
        var headCY: CGFloat, headR: CGFloat
        switch pose {
        case "stretch": bodyCY = 46; bodyRX = 12; bodyRY = 20 + breathe; headCY = 17; headR = 13
        case "crouch":  bodyCY = 54; bodyRX = 18; bodyRY = 12 + breathe; headCY = 36; headR = 14
        case "sleep":   bodyCY = 56; bodyRX = 20; bodyRY = 12 + breathe; headCY = 47; headR = 13
        default:        bodyCY = 50; bodyRX = 15; bodyRY = 16 + breathe; headCY = 29; headR = 15
        }

        // tail
        let tailWave = CGFloat(sin(Double(m.tailPhase))) * (pose == "crouch" ? 7 : 5)
        var tail = Path()
        tail.move(to: CGPoint(x: CX + bodyRX - 2, y: bodyCY + 6))
        tail.addQuadCurve(
            to: CGPoint(x: CX + bodyRX + 8, y: bodyCY - 10 + tailWave),
            control: CGPoint(x: CX + bodyRX + 12, y: bodyCY + 2 + tailWave))
        c.stroke(tail, with: .color(P.outline), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        c.stroke(tail, with: .color(P.base), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // body + belly
        el(&c, CX, bodyCY, bodyRX, bodyRY, fill: P.base, stroke: P.outline, lw: 1.6)
        if pose == "sleep" {
            el(&c, CX, bodyCY + 2, bodyRX - 5, bodyRY - 3, fill: P.belly)
        } else {
            el(&c, CX, bodyCY + bodyRY * 0.35, bodyRX * 0.62, bodyRY * 0.7, fill: P.belly)
        }

        // limbs
        if pose == "sit" || pose == "crouch" {
            let footY = BASEY - (pose == "crouch" ? 2 : 0)
            el(&c, CX - bodyRX + 3, footY - 2, 5, 4, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX + bodyRX - 3, footY - 2, 5, 4, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX - 6, footY, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX + 6, footY, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
        } else if pose == "stretch" {
            var arms = Path()
            arms.move(to: CGPoint(x: CX - 7, y: 30)); arms.addLine(to: CGPoint(x: CX - 10, y: 16))
            arms.move(to: CGPoint(x: CX + 7, y: 30)); arms.addLine(to: CGPoint(x: CX + 10, y: 16))
            c.stroke(arms, with: .color(P.base), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            el(&c, CX - 10, 15, 3, 3, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX + 10, 15, 3, 3, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX - 6, BASEY, 4.5, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX + 6, BASEY, 4.5, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
        } else if pose == "sleep" {
            el(&c, CX - 12, bodyCY + 6, 5, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
            el(&c, CX + 13, bodyCY + 5, 5, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
        }

        // head
        drawHead(&c, P, hx: CX + m.lean, hy: headCY, hr: headR, pose: pose, eye: eye, m: m)
    }

    private static func drawHead(_ c: inout GraphicsContext, _ P: Palette,
                                 hx: CGFloat, hy: CGFloat, hr: CGFloat,
                                 pose: String, eye: String, m: CatModel) {
        let earBack = pose == "crouch"
        let earY = hy - hr * 0.55
        let spread = earBack ? hr * 0.95 : hr * 0.72
        let earLift: CGFloat = earBack ? 3 : 0
        drawEar(&c, P, x: hx - spread, y: earY + earLift, dir: -1, back: earBack)
        drawEar(&c, P, x: hx + spread, y: earY + earLift, dir: 1, back: earBack)

        // face
        el(&c, hx, hy, hr, hr * 0.92, fill: P.base, stroke: P.outline, lw: 1.6)

        // forehead stripes
        if P.stripes {
            var s = Path()
            s.move(to: CGPoint(x: hx - 4, y: hy - hr * 0.7)); s.addLine(to: CGPoint(x: hx - 3, y: hy - hr * 0.35))
            s.move(to: CGPoint(x: hx, y: hy - hr * 0.78)); s.addLine(to: CGPoint(x: hx, y: hy - hr * 0.4))
            s.move(to: CGPoint(x: hx + 4, y: hy - hr * 0.7)); s.addLine(to: CGPoint(x: hx + 3, y: hy - hr * 0.35))
            c.stroke(s, with: .color(P.stripe), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }

        // muzzle
        let muzY = hy + hr * 0.28
        el(&c, hx, muzY + 1, hr * 0.6, hr * 0.42, fill: P.belly)

        // blush
        if m.blush {
            c.opacity = 0.75
            el(&c, hx - hr * 0.62, hy + 2, 2.6, 1.8, fill: P.pink)
            el(&c, hx + hr * 0.62, hy + 2, 2.6, 1.8, fill: P.pink)
            c.opacity = 1
        }

        // eyes
        let ex = hr * 0.46
        let ey = hy - 1
        drawEye(&c, P, x: hx - ex, y: ey, eye: eye, m: m)
        drawEye(&c, P, x: hx + ex, y: ey, eye: eye, m: m)

        // nose
        var nose = Path()
        nose.move(to: CGPoint(x: hx, y: muzY - 1))
        nose.addLine(to: CGPoint(x: hx - 1.8, y: muzY - 2.4))
        nose.addLine(to: CGPoint(x: hx + 1.8, y: muzY - 2.4))
        nose.closeSubpath()
        c.fill(nose, with: .color(P.pink))

        // mouth
        var mouth = Path()
        if eye == "happy" || pose == "stretch" {
            mouth.move(to: CGPoint(x: hx - 2.5, y: muzY + 1.5))
            mouth.addQuadCurve(to: CGPoint(x: hx + 2.5, y: muzY + 1.5),
                               control: CGPoint(x: hx, y: muzY + 4.5))
        } else {
            mouth.move(to: CGPoint(x: hx, y: muzY - 1))
            mouth.addLine(to: CGPoint(x: hx, y: muzY + 1.2))
            mouth.move(to: CGPoint(x: hx, y: muzY + 1.2))
            mouth.addQuadCurve(to: CGPoint(x: hx - 3.4, y: muzY + 1.4),
                               control: CGPoint(x: hx - 2, y: muzY + 2.6))
            mouth.move(to: CGPoint(x: hx, y: muzY + 1.2))
            mouth.addQuadCurve(to: CGPoint(x: hx + 3.4, y: muzY + 1.4),
                               control: CGPoint(x: hx + 2, y: muzY + 2.6))
        }
        c.stroke(mouth, with: .color(P.outline), style: StrokeStyle(lineWidth: 1, lineCap: .round))

        // whiskers
        c.opacity = 0.55
        var wh = Path()
        for s in [CGFloat(-1), CGFloat(1)] {
            wh.move(to: CGPoint(x: hx + s * hr * 0.5, y: muzY - 1))
            wh.addLine(to: CGPoint(x: hx + s * (hr + 5), y: muzY - 3))
            wh.move(to: CGPoint(x: hx + s * hr * 0.5, y: muzY + 1))
            wh.addLine(to: CGPoint(x: hx + s * (hr + 5), y: muzY + 1))
        }
        c.stroke(wh, with: .color(P.outline), lineWidth: 0.8)
        c.opacity = 1
    }

    private static func drawEar(_ c: inout GraphicsContext, _ P: Palette,
                                x: CGFloat, y: CGFloat, dir: CGFloat, back: Bool) {
        var outer = Path()
        if back {
            outer.move(to: CGPoint(x: x - dir * 2, y: y + 4))
            outer.addLine(to: CGPoint(x: x + dir * 7, y: y + 1))
            outer.addLine(to: CGPoint(x: x + dir * 2, y: y + 6))
        } else {
            outer.move(to: CGPoint(x: x - dir * 4, y: y + 5))
            outer.addLine(to: CGPoint(x: x + dir * 1.5, y: y - 5))
            outer.addLine(to: CGPoint(x: x + dir * 5, y: y + 4))
        }
        outer.closeSubpath()
        c.fill(outer, with: .color(P.base))
        c.stroke(outer, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))

        var inner = Path()
        if back {
            inner.move(to: CGPoint(x: x + dir * 0.5, y: y + 3.5))
            inner.addLine(to: CGPoint(x: x + dir * 5, y: y + 1.8))
            inner.addLine(to: CGPoint(x: x + dir * 2, y: y + 5))
        } else {
            inner.move(to: CGPoint(x: x - dir * 1.5, y: y + 3.5))
            inner.addLine(to: CGPoint(x: x + dir * 1.5, y: y - 2))
            inner.addLine(to: CGPoint(x: x + dir * 3, y: y + 3))
        }
        inner.closeSubpath()
        c.fill(inner, with: .color(P.pink))
    }

    private static func drawEye(_ c: inout GraphicsContext, _ P: Palette,
                                x: CGFloat, y: CGFloat, eye: String, m: CatModel) {
        switch eye {
        case "happy":
            var a = Path()
            a.addArc(center: CGPoint(x: x, y: y + 1), radius: 2.6,
                     startAngle: .radians(Double.pi * 1.05),
                     endAngle: .radians(Double.pi * 1.95), clockwise: false)
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            return
        case "sleep":
            var a = Path()
            a.addArc(center: CGPoint(x: x, y: y - 1), radius: 2.6,
                     startAngle: .radians(Double.pi * 0.1),
                     endAngle: .radians(Double.pi * 0.9), clockwise: false)
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            return
        case "dizzy":
            var a = Path()
            a.move(to: CGPoint(x: x - 2, y: y - 2)); a.addLine(to: CGPoint(x: x + 2, y: y + 2))
            a.move(to: CGPoint(x: x + 2, y: y - 2)); a.addLine(to: CGPoint(x: x - 2, y: y + 2))
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            return
        default:
            break
        }

        let wide = eye == "wide"
        let ryFull: CGFloat = wide ? 4.2 : 3.6
        let ry = ryFull * (1 - m.blink)
        if ry < 0.6 {
            var line = Path()
            line.move(to: CGPoint(x: x - 2.6, y: y)); line.addLine(to: CGPoint(x: x + 2.6, y: y))
            c.stroke(line, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            return
        }
        el(&c, x, y, wide ? 3.2 : 2.7, ry, fill: P.sclera, stroke: P.outline, lw: 1)
        let px = x + clamp(m.pupX, -1.2, 1.2)
        let py = y + clamp(m.pupY, -1.4, 1.6)
        el(&c, px, py, wide ? 2.0 : 1.5, min(ry - 0.3, wide ? 3.0 : 2.2), fill: P.eye)
        el(&c, px - 0.6, py - 0.8, 0.6, 0.6, fill: Color.white.opacity(0.9))
    }

    // MARK: - helpers

    static func el(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
                   _ rx: CGFloat, _ ry: CGFloat,
                   fill: Color? = nil, stroke: Color? = nil, lw: CGFloat = 1.4) {
        let p = Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
        if let f = fill { c.fill(p, with: .color(f)) }
        if let s = stroke { c.stroke(p, with: .color(s), lineWidth: lw) }
    }

    static func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        max(a, min(b, v))
    }
}
