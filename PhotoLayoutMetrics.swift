import CoreGraphics
import Foundation

// Geometry only. SwiftUI Layout owns interpolation; no per-frame simulation.
struct PhotoLayoutMetrics {
    let deckSize: CGSize
    let gridSize: CGSize
    let deckCards: [CGSize]
    let gridCards: [CGRect]
    let columns: Int

    init(aspects: [CGFloat], deckWidth: CGFloat, gridWidth: CGFloat) {
        let compactWidth = deckWidth.isFinite ? max(1, deckWidth) : 252
        let expandedWidth = gridWidth.isFinite ? max(1, gridWidth) : compactWidth
        let ratios = aspects.map { $0.isFinite && $0 > 0 ? $0 : 1 }
        let margin = min(14, compactWidth * 0.08)
        let cardWidth = max(1, compactWidth - margin * 2)
        let cardHeight = min(224, compactWidth * 0.88)
        deckCards = ratios.map { Self.fit($0, width: cardWidth, height: cardHeight) }
        deckSize = CGSize(width: compactWidth,
                          height: (deckCards.map(\.height).max() ?? 0) + margin * 2)

        columns = min(3, max(1, ratios.count))
        let gap = min(10, expandedWidth * 0.03)
        let columnWidth = max(1, (expandedWidth - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let sizes = ratios.map { Self.fit($0, width: columnWidth, height: columnWidth * 1.8) }
        var frames: [CGRect] = []
        var top: CGFloat = 0
        for start in stride(from: 0, to: sizes.count, by: columns) {
            let end = min(start + columns, sizes.count)
            let rowHeight = sizes[start..<end].map(\.height).max() ?? 0
            for index in start..<end {
                let size = sizes[index]
                let x = CGFloat(index - start) * (columnWidth + gap) + (columnWidth - size.width) / 2
                frames.append(CGRect(x: x, y: top + (rowHeight - size.height) / 2,
                                     width: size.width, height: size.height))
            }
            top += rowHeight + gap
        }
        gridCards = frames
        gridSize = CGSize(width: expandedWidth, height: max(0, top - (sizes.isEmpty ? 0 : gap)))
    }

    static func depth(of index: Int, front: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index - front) % count + count) % count
    }

    private static func fit(_ aspect: CGFloat, width: CGFloat, height: CGFloat) -> CGSize {
        let fittedWidth = min(width, height * aspect)
        return CGSize(width: fittedWidth, height: fittedWidth / aspect)
    }
}
