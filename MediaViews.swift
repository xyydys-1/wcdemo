import SwiftUI

struct StoredPhoto: View {
    @EnvironmentObject private var store: DemoStore
    let key: String
    var contentMode: ContentMode = .fill
    var body: some View {
        Group {
            if let image = store.media.image(key) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                ZStack { Color.secondary.opacity(0.10); Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
    }
}

@available(iOS 26.0, *)
struct PhotoStackMessage: View {
    @EnvironmentObject private var store: DemoStore
    let keys: [String]
    let width: CGFloat
    @State private var expanded = false
    @State private var frontIndex = 0
    @State private var drag = CGSize.zero
    @State private var dragging = false
    @State private var previewKey: String?

    private let follow: [CGFloat] = [1, 0.40, 0.20, 0.10, 0.05]
    private let blurs: [CGFloat] = [0, 2.8, 4.3, 5.6, 6.8]

    var body: some View {
        Group {
            if expanded { expandedGrid } else { collapsedDeck }
        }
        .animation(.spring(duration: 0.48, bounce: 0.18), value: expanded)
        .fullScreenCover(isPresented: Binding(get: { previewKey != nil }, set: { if !$0 { previewKey = nil } })) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let key = previewKey { StoredPhoto(key: key, contentMode: .fit).padding(14) }
            }
            .overlay(alignment: .topTrailing) {
                Button { previewKey = nil } label: { Image(systemName: "xmark").font(.title2).frame(width: 46,height:46) }
                    .buttonStyle(.glass).padding()
            }
        }
    }

    private var ordered: [String] {
        guard !keys.isEmpty else { return [] }
        return (0..<keys.count).map { keys[(frontIndex + $0) % keys.count] }
    }

    private var collapsedDeck: some View {
        let visible = Array(ordered.prefix(5))
        return ZStack {
            ForEach(Array(visible.enumerated()).reversed(), id: \.element) { depth, key in
                let ratio = store.media.aspect(key)
                let cardWidth = min(width - 14, 238)
                let cardHeight = min(230, max(132, cardWidth / ratio))
                let f = follow[min(depth, follow.count - 1)]
                StoredPhoto(key: key)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .blur(radius: blurs[min(depth, blurs.count - 1)])
                    .photoEdge(cornerRadius: 17)
                    .compositingGroup()
                    .rotationEffect(.degrees(Double(depth - 2) * 2.5 + Double(drag.width / 28 * f)))
                    .offset(x: CGFloat(depth) * 5 + drag.width * f,
                            y: CGFloat(depth) * 6 + drag.height * f)
                    .scaleEffect(1 - CGFloat(depth) * 0.018)
                    .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                    .animation(.interactiveSpring(response: 0.22 + Double(depth) * 0.08, dampingFraction: 0.76), value: drag)
                    .zIndex(Double(10-depth))
                    .onTapGesture { if !dragging { expanded = true } }
                    .onLongPressGesture { previewKey = key }
            }
        }
        .frame(width: width, height: 255)
        .contentShape(Rectangle())
        .gesture(PhotoPanGesture(enabled: keys.count > 1,
            changed: { offset in dragging = true; drag = CGSize(width: max(-width*0.58,min(width*0.58,offset.width)), height: max(-30,min(30,offset.height*0.45))) },
            ended: { offset, velocity in
                let switchCard = abs(offset.width) > width*0.24 || abs(velocity.width) > 720
                withAnimation(.spring(duration: 0.48, bounce: 0.20)) { drag = .zero }
                if switchCard && !keys.isEmpty { frontIndex = (frontIndex + 1) % keys.count }
                DispatchQueue.main.asyncAfter(deadline: .now()+0.12) { dragging = false }
            },
            cancelled: { withAnimation(.spring(duration: 0.42, bounce: 0.18)) { drag = .zero }; dragging = false }))
    }

    private var expandedGrid: some View {
        let columns = keys.count >= 3 ? 3 : max(1, keys.count)
        let rows = stride(from: 0, to: ordered.count, by: columns).map { Array(ordered[$0..<min($0+columns, ordered.count)]) }
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        StoredPhoto(key: key, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .photoEdge(cornerRadius: 11)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let idx = keys.firstIndex(of: key) { frontIndex = idx }
                                expanded = false
                            }
                            .onLongPressGesture { previewKey = key }
                    }
                    if row.count < columns {
                        ForEach(0..<(columns-row.count), id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
                    }
                }
            }
        }
        .frame(width: min(width + 78, 340))
    }
}
