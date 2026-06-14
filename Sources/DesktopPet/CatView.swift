import SwiftUI

struct CatView: View {
    @ObservedObject var engine: PetEngine

    var body: some View {
        ZStack {
            Canvas { context, size in
                engine.render(into: &context, size: size)
            }

            if let text = engine.bubbleText {
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4A3320"))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#6B4423"), lineWidth: 1.5))
                    .position(x: Layout.PW / 2, y: Layout.PH - Layout.bottomMargin - Layout.displayH - 17)
            }

            if let text = engine.timerText {
                Text(text)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#3D4650"))
                    .frame(width: 92, height: 20)
                    .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#6B4423"), lineWidth: 1))
                    .position(x: Layout.PW / 2, y: Layout.PH - 16)
            }
        }
        .frame(width: Layout.PW, height: Layout.PH)
        .allowsHitTesting(false) // interaction is handled by polling in the engine
    }
}
