import SwiftUI

private struct PhotoEdgeModifier: ViewModifier {
    let corner: CGFloat
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        content
            .clipShape(shape, style: FillStyle(antialiased: true))
            .overlay {
                shape.strokeBorder(.white.opacity(scheme == .dark ? 0.34 : 0.44), lineWidth: max(0.5, 1 / displayScale), antialiased: true)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func photoEdge(cornerRadius: CGFloat) -> some View { modifier(PhotoEdgeModifier(corner: cornerRadius)) }
}
