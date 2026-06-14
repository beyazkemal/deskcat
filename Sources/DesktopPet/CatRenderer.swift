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
        case .pet, .celebrate: eye = "happy"
        case .sleep: pose = "sleep"; eye = "sleep"
        case .drag: eye = "dizzy"
        case .stretch: pose = "stretch"; eye = "happy"
        case .scroll: pose = "sit"; eye = "happy"
        case .type, .thinking: pose = "sit"; eye = "open"
        case .overheat: pose = "sit"; eye = "strain"
        case .tailPull, .angry: pose = "sit"; eye = "angry"
        case .sad: pose = "sit"; eye = "sad"
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
        let angry = m.state == .tailPull || m.state == .angry
        let tailWave = CGFloat(sin(Double(m.tailPhase))) * (angry ? 10 : (pose == "crouch" ? 7 : 5))
        let tailEnd = m.state == .tailPull
            ? CGPoint(x: CX + m.tailPullX, y: bodyCY + m.tailPullY)
            : CGPoint(x: CX + bodyRX + 8, y: bodyCY - 10 + tailWave)
        var tail = Path()
        tail.move(to: CGPoint(x: CX + bodyRX - 2, y: bodyCY + 6))
        tail.addQuadCurve(
            to: tailEnd,
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
            if m.state == .type || m.state == .overheat {
                drawKeyboard(&c, m)
                // Paws rest above the keyboard, then push down onto a key.
                el(&c, CX - 6, footY - 5 + m.pawTapL * 4, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
                el(&c, CX + 6, footY - 5 + m.pawTapR * 4, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
            } else if m.state == .scroll {
                drawToiletPaper(&c, m)
                let pawStroke = CGFloat((sin(Double(m.tailPhase * 5.2)) + 1) * 0.5)
                el(&c, 17, 47 + pawStroke * 6, 3.8, 3.2,
                   fill: P.belly, stroke: P.outline, lw: 1.1)
            } else {
                el(&c, CX - 6, footY, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
                el(&c, CX + 6, footY, 4, 3.5, fill: P.belly, stroke: P.outline, lw: 1.2)
            }
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

        // overheat flush — translucent red over body + head, grows with heat
        if m.heat > 0.02 {
            c.opacity = Double(min(0.55, m.heat * 0.5))
            let red = Color(hex: "#F2563A")
            el(&c, CX, bodyCY, bodyRX, bodyRY, fill: red)
            el(&c, CX + m.lean, headCY, headR, headR * 0.92, fill: red)
            c.opacity = 1
        }

        if angry {
            var mark = Path()
            mark.move(to: CGPoint(x: CX + 20, y: 8))
            mark.addLine(to: CGPoint(x: CX + 25, y: 4))
            mark.move(to: CGPoint(x: CX + 20, y: 4))
            mark.addLine(to: CGPoint(x: CX + 25, y: 8))
            c.stroke(mark, with: .color(Color(hex: "#D83A35")),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        if m.state == .thinking {
            for index in 0..<3 {
                el(&c, CX + 18 + CGFloat(index * 5), 11 - CGFloat(index * 3),
                   1.5 + CGFloat(index) * 0.35, 1.5 + CGFloat(index) * 0.35,
                   fill: Color(hex: "#7C8AA0"))
            }
        }
    }

    private static func drawKeyboard(_ c: inout GraphicsContext, _ m: CatModel) {
        let outline = Color(hex: "#343A40")
        let caseColor = Color(hex: "#737D87")
        let keyColor = Color(hex: "#E9EDF0")
        let pressedColor = Color(hex: "#A9D5F2")

        let keyboard = Path(roundedRect: CGRect(x: 12, y: 63, width: 40, height: 9), cornerRadius: 2)
        c.fill(keyboard, with: .color(caseColor))
        c.stroke(keyboard, with: .color(outline), lineWidth: 1)

        for index in 0..<7 {
            let x = CGFloat(16 + index * 5)
            let isLeftKey = index == 2
            let isRightKey = index == 4
            let press = isLeftKey ? m.pawTapL : (isRightKey ? m.pawTapR : 0)
            let y = CGFloat(65.5) + press * 1.2
            let key = Path(roundedRect: CGRect(x: x - 1.8, y: y - 1.5, width: 3.6, height: 3), cornerRadius: 0.7)
            c.fill(key, with: .color(press > 0.2 ? pressedColor : keyColor))
            c.stroke(key, with: .color(outline.opacity(0.75)), lineWidth: 0.55)
        }

        let spacePress = max(m.pawTapL, m.pawTapR) * 0.45
        let space = Path(roundedRect: CGRect(x: 25, y: 69 + spacePress, width: 14, height: 1.5), cornerRadius: 0.6)
        c.fill(space, with: .color(keyColor))
        c.stroke(space, with: .color(outline.opacity(0.75)), lineWidth: 0.45)
    }

    private static func drawToiletPaper(_ c: inout GraphicsContext, _ m: CatModel) {
        let outline = Color(hex: "#77736D")
        let paper = Color(hex: "#FFFDF7")
        let shadow = Color(hex: "#E5E2DC")
        let rollX: CGFloat = 7
        let rollY: CGFloat = 44
        let sheetTop = rollY + 3
        let sheetBottom: CGFloat = 65

        // The sheet stays the same length. Moving marks make it read as paper
        // continuously feeding downward instead of stretching like elastic.
        let sheet = Path(roundedRect: CGRect(x: 7, y: sheetTop, width: 9, height: sheetBottom - sheetTop),
                         cornerRadius: 0.8)
        c.fill(sheet, with: .color(paper))
        c.stroke(sheet, with: .color(outline), lineWidth: 0.9)

        let feedOffset = CGFloat(Double(m.tailPhase * 3.2).truncatingRemainder(dividingBy: 7))
        for row in 0..<3 {
            let y = sheetTop + 5 + CGFloat(row * 7) + feedOffset
            guard y < sheetBottom - 1 else { continue }
            var perforation = Path()
            for column in 0..<3 {
                let x = CGFloat(8.2 + Double(column) * 2.5)
                perforation.move(to: CGPoint(x: x, y: y))
                perforation.addLine(to: CGPoint(x: x + 1.1, y: y))
            }
            c.stroke(perforation, with: .color(shadow), lineWidth: 0.65)
        }

        // Compact side-facing roll, clearly beside the cat.
        el(&c, rollX, rollY, 7, 6, fill: paper, stroke: outline, lw: 1.1)
        el(&c, rollX, rollY, 3.8, 3.4, fill: shadow, stroke: outline, lw: 0.8)
        el(&c, rollX, rollY, 1.6, 1.5, fill: Color(hex: "#B89B75"), stroke: outline, lw: 0.65)

        let spin = Angle.radians(Double(m.tailPhase * 5.2))
        var curl = Path()
        curl.addArc(center: CGPoint(x: rollX, y: rollY), radius: 4.8,
                    startAngle: spin, endAngle: spin + .degrees(115), clockwise: false)
        c.stroke(curl, with: .color(shadow), lineWidth: 0.8)
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
        if eye == "strain" {
            // open panting mouth
            el(&c, hx, muzY + 1.8, 1.8, 2.2, fill: Color(hex: "#7A3B3B"))
        } else {
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
        }

        // sweat drop when overheating
        if eye == "strain" {
            el(&c, hx + hr * 0.85, hy + 2, 1.6, 2.2, fill: Color(hex: "#8EC9F0"))
        }

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
        case "strain":
            // squeezed-shut "^" eyes
            var a = Path()
            a.move(to: CGPoint(x: x - 2.4, y: y + 1.6))
            a.addLine(to: CGPoint(x: x, y: y - 1.4))
            a.addLine(to: CGPoint(x: x + 2.4, y: y + 1.6))
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            return
        case "angry":
            var a = Path()
            a.move(to: CGPoint(x: x - 2.8, y: y - 2))
            a.addLine(to: CGPoint(x: x + 2.8, y: y))
            a.move(to: CGPoint(x: x - 2.3, y: y + 1.8))
            a.addLine(to: CGPoint(x: x + 2.3, y: y + 1.8))
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            return
        case "sad":
            var a = Path()
            a.addArc(center: CGPoint(x: x, y: y + 2), radius: 2.6,
                     startAngle: .radians(Double.pi * 1.1),
                     endAngle: .radians(Double.pi * 1.9), clockwise: false)
            c.stroke(a, with: .color(P.outline), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
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
