import SwiftUI
import Observation
import UIKit

// One persistent hierarchy switches layout. Native springs interpolate both
// placement and proposed image size without replacing the photo views.
private struct PhotoPileLayout: Layout {
    let metrics: PhotoLayoutMetrics
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        metrics.deckSize
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, view) in subviews.enumerated() where index < metrics.deckCards.count {
            let size = metrics.deckCards[index]
            view.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                       proposal: ProposedViewSize(width: size.width, height: size.height))
        }
    }
}

private struct PhotoRowsLayout: Layout {
    let metrics: PhotoLayoutMetrics
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        metrics.gridSize
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, view) in subviews.enumerated() where index < metrics.gridCards.count {
            let frame = metrics.gridCards[index]
            view.place(at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY),
                       anchor: .center, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

@Observable
private final class PhotoDragState {
    var translation = CGSize.zero
    var active = false
    var suppressTapUntil = Date.distantPast

    func reset() {
        active = false
        translation = .zero
    }
    func endDrag() {
        if active { suppressTapUntil = Date().addingTimeInterval(0.18) }
        reset()
    }
}

// Only this modifier observes the continuous gesture. Neither the chat layout
// nor image decoding is invalidated for each finger movement.
private struct PhotoDragMotion: ViewModifier {
    let motion: PhotoDragState
    let depth: Int
    let width: CGFloat
    let expanded: Bool
    let reduceMotion: Bool

    private var response: Animation {
        if reduceMotion { return .linear(duration: 0.08) }
        if motion.active {
            return .interactiveSpring(response: 0.13 + Double(depth) * 0.045,
                                      dampingFraction: 0.80, blendDuration: 0.12)
        }
        return .interpolatingSpring(duration: 0.42 + Double(depth) * 0.035,
                                    bounce: depth == 0 ? 0.12 : 0.26)
    }

    func body(content: Content) -> some View {
        let amount = expanded ? CGSize.zero : motion.translation
        let follow = CGFloat(pow(0.78, Double(depth)))
        let tilt = reduceMotion ? 0 : Double(amount.width / max(1, width)) * 19 * Double(follow)
        content
            .rotationEffect(.degrees(tilt))
            .offset(x: amount.width * follow, y: amount.height * follow)
            .animation(response, value: amount)
    }
}

// The image subtree is rasterized before it is rotated. The inset edge is drawn
// AFTER the depth blur, so rear cards retain a clean, continuous silhouette.
private struct PhotoCardSurface: View {
    let media: LocalMediaFiles
    let key: String
    let visible: Bool
    let depth: Int
    let expanded: Bool
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    private var pixels: Int { expanded ? 384 : 960 }
    private var imageRequest: String { "\(key):\(visible):\(pixels)" }
    private var corner: CGFloat { expanded ? 10 : 13 }
    private var blur: CGFloat { expanded ? 0 : min(2.8, CGFloat(depth) * 0.7) }

    var body: some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
            Group {
                if let photo = image ?? (visible ? media.image(key, maxPixel: 96) : nil) {
                    Image(uiImage: photo).resizable().interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(uiColor: .tertiarySystemFill)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .blur(radius: blur)
            .clipShape(shape, style: FillStyle(antialiased: true))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.46 : 0.62),
                                             .white.opacity(0.10), .black.opacity(0.16)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: max(0.5, 1 / displayScale), antialiased: true)
            }
            // A transparent pixel around the texture lets rotated straight edges
            // interpolate too; it does not change the card's layout size.
            .padding(1 / displayScale)
            .drawingGroup(opaque: false)
            .padding(-1 / displayScale)
            .shadow(color: .black.opacity(expanded ? 0.09 : 0.18),
                    radius: expanded ? 1.5 : 4, x: 0, y: expanded ? 1 : 2)
        }
        .task(id: imageRequest) {
            guard visible else { image = nil; return }
            // Decode at display size, off the main thread; depth changes reuse it.
            let files = media, source = key, pixelLimit = pixels
            let loaded = await Task.detached(priority: .userInitiated) {
                files.image(source, maxPixel: pixelLimit)
            }.value
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { image = loaded }
        }
    }
}

@available(iOS 26.0, *)
struct PhotoStackMessage: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let keys: [String]
    let width: CGFloat
    let expandedWidth: CGFloat
    @State private var expanded = false
    @State private var frontIndex = 0
    @State private var preview: PhotoPresentation?
    @State private var motion = PhotoDragState()
    @GestureState private var touching = false

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.46, bounce: 0.18)
    }

    var body: some View {
        let metrics = PhotoLayoutMetrics(aspects: keys.map { store.media.aspect($0) },
                                         deckWidth: width, gridWidth: expandedWidth)
        let layout = expanded ? AnyLayout(PhotoRowsLayout(metrics: metrics))
                              : AnyLayout(PhotoPileLayout(metrics: metrics))
        layout {
            ForEach(keys.indices, id: \.self) { index in
                card(index, count: keys.count)
            }
        }
        .frame(width: expanded ? metrics.gridSize.width : metrics.deckSize.width,
               height: expanded ? metrics.gridSize.height : metrics.deckSize.height)
        // Simultaneous recognition lets vertical drags continue scrolling history.
        .simultaneousGesture(drag)
        .onChange(of: touching) { _, active in
            if !active { motion.endDrag() }
        }
        .onDisappear { motion.reset() }
        .fullScreenCover(item: $preview) { NativePhotoPreview(presentation: $0).ignoresSafeArea() }
        .accessibilityElement(children: expanded ? .contain : .ignore)
        .accessibilityLabel("\(keys.count)张照片，第\(frontIndex + 1)张在最上面")
        .accessibilityHint("轻点展开，横向拖动翻动，长按查看大图")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { select(frontIndex) }
        .accessibilityAction(named: Text("查看大图")) { showPreview(frontIndex) }
        .accessibilityAdjustableAction { direction in
            guard !keys.isEmpty else { return }
            withAnimation(animation) {
                switch direction {
                case .increment: frontIndex = (frontIndex + 1) % keys.count
                case .decrement: frontIndex = (frontIndex + keys.count - 1) % keys.count
                @unknown default: break
                }
            }
        }
    }

    private func card(_ index: Int, count: Int) -> some View {
        let depth = PhotoLayoutMetrics.depth(of: index, front: frontIndex, count: count)
        let visible = expanded || depth < 5
        let angle: Double = expanded || reduceMotion ? 0 : [0, 6, -9, 11, -13][min(depth, 4)]
        return PhotoCardSurface(media: store.media, key: keys[index], visible: visible,
                                depth: depth, expanded: expanded)
            .contentShape(RoundedRectangle(cornerRadius: expanded ? 10 : 13, style: .continuous))
            .onTapGesture { select(index) }
            .onLongPressGesture { showPreview(index) }
            .scaleEffect(expanded ? 1 : max(0.85, 1 - CGFloat(depth) * 0.028))
            .rotationEffect(.degrees(angle))
            .offset(x: expanded ? 0 : CGFloat(depth % 2 == 0 ? -depth : depth) * 1.1,
                    y: expanded ? 0 : CGFloat(min(depth, 4)) * 1.6)
            .modifier(PhotoDragMotion(motion: motion, depth: min(depth, 4), width: width,
                                      expanded: expanded, reduceMotion: reduceMotion))
            .opacity(visible ? 1 : 0)
            .zIndex(expanded ? Double(count - index) : Double(count - depth))
            .allowsHitTesting(visible && (expanded || depth == 0))
            .accessibilityHidden(!visible)
            .accessibilityLabel("照片 \(index + 1)")
            .accessibilityHint(expanded ? "轻点收起并作为封面，长按查看大图" : "轻点展开")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("查看大图")) { showPreview(index) }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard !expanded, keys.count > 1 else { return }
                let offset = value.translation
                guard motion.active || abs(offset.width) > abs(offset.height) * 1.2 else { return }
                var transaction = Transaction()
                transaction.isContinuous = true
                withTransaction(transaction) {
                    motion.active = true
                    motion.translation = CGSize(width: max(-width * 0.62, min(width * 0.62, offset.width)),
                                                height: max(-32, min(32, offset.height * 0.45)))
                }
            }
            .onEnded { value in
                guard motion.active else { return }
                let distance = value.translation.width
                let deliberate = abs(distance) > width * 0.28
                    || (abs(distance) > width * 0.16 && abs(value.velocity.width) > 650)
                if deliberate && !keys.isEmpty {
                    withAnimation(animation) {
                        frontIndex = (frontIndex + (distance < 0 ? 1 : keys.count - 1)) % keys.count
                    }
                }
                motion.endDrag()
            }
    }

    private func select(_ index: Int) {
        guard !keys.isEmpty, Date() >= motion.suppressTapUntil else { return }
        if keys.count == 1 { showPreview(0); return }
        motion.reset()
        withAnimation(animation) {
            if expanded { frontIndex = index }
            expanded.toggle()
        }
    }
    private func showPreview(_ index: Int) {
        guard keys.indices.contains(index) else { return }
        motion.reset()
        preview = PhotoPresentation(keys: keys, index: index)
    }
}
