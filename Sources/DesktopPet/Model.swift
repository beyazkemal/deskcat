import SwiftUI

enum PetState: String {
    case idle, look, pet, sleep, drag, stretch, walk
    case type, overheat, tailPull, angry, scroll
    case thinking, celebrate, sad
}

enum PomodoroPhase: String {
    case focus = "Focus"
    case breakTime = "Break"
}

// Color from hex string ("#RRGGBB")
extension Color {
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xff) / 255.0
        let g = Double((v >> 8) & 0xff) / 255.0
        let b = Double(v & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

struct Palette {
    let base, shade, belly, stripe, outline, pink, sclera, eye: Color
    let stripes: Bool
}

enum Palettes {
    static let orange = Palette(
        base: Color(hex: "#F2A24E"), shade: Color(hex: "#E0892F"),
        belly: Color(hex: "#FBE4C5"), stripe: Color(hex: "#CE7A2A"),
        outline: Color(hex: "#6B4423"), pink: Color(hex: "#F39AA6"),
        sclera: Color(hex: "#FFFFFF"), eye: Color(hex: "#3A2A1F"), stripes: true)

    static let gray = Palette(
        base: Color(hex: "#B7BEC6"), shade: Color(hex: "#99A2AB"),
        belly: Color(hex: "#EDF0F3"), stripe: Color(hex: "#8B939C"),
        outline: Color(hex: "#4C535A"), pink: Color(hex: "#F39AA6"),
        sclera: Color(hex: "#FFFFFF"), eye: Color(hex: "#2D343A"), stripes: true)

    static let cream = Palette(
        base: Color(hex: "#F4E5CB"), shade: Color(hex: "#E8D2A9"),
        belly: Color(hex: "#FDF6E9"), stripe: Color(hex: "#E1C28E"),
        outline: Color(hex: "#9A7E54"), pink: Color(hex: "#F39AA6"),
        sclera: Color(hex: "#FFFFFF"), eye: Color(hex: "#5A4632"), stripes: true)

    static let tuxedo = Palette(
        base: Color(hex: "#33373B"), shade: Color(hex: "#26292C"),
        belly: Color(hex: "#F5F5F5"), stripe: Color(hex: "#33373B"),
        outline: Color(hex: "#16181A"), pink: Color(hex: "#F39AA6"),
        sclera: Color(hex: "#FBFBF2"), eye: Color(hex: "#BFD46A"), stripes: false)

    static func byName(_ name: String) -> Palette {
        switch name {
        case "gray": return gray
        case "cream": return cream
        case "tuxedo": return tuxedo
        default: return orange
        }
    }
}

// Everything the renderer needs for one frame.
struct CatModel {
    var state: PetState = .idle
    var pupX: CGFloat = 0
    var pupY: CGFloat = 0
    var lean: CGFloat = 0
    var blink: CGFloat = 0       // 0 open .. 1 closed
    var breathe: CGFloat = 0
    var tailPhase: CGFloat = 0
    var squash: CGFloat = 1
    var squashX: CGFloat = 1
    var bounce: CGFloat = 0
    var blush: Bool = false
    var pawTapL: CGFloat = 0   // 0..1 paw tap impulse (typing)
    var pawTapR: CGFloat = 0
    var heat: CGFloat = 0      // 0..1 overheat tint
    var tailPullX: CGFloat = 0
    var tailPullY: CGFloat = 0
    var scrollAmount: CGFloat = 0
    var bubbleText: String?
    var timerText: String?
    var palette: Palette = Palettes.orange
}
