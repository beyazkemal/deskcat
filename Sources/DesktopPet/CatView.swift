import SwiftUI

struct CatView: View {
    @ObservedObject var engine: PetEngine

    var body: some View {
        Canvas { context, size in
            engine.render(into: &context, size: size)
        }
        .frame(width: Layout.PW, height: Layout.PH)
        .allowsHitTesting(false) // interaction is handled by polling in the engine
    }
}
