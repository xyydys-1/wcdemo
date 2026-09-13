import CoreGraphics
import Foundation

extension LocalDataTests {
    static func photoLayoutTests() throws {
        let landscapeAspect: CGFloat = 16.0 / 9.0
        let portraitAspect: CGFloat = 9.0 / 16.0
        let panoramicAspect: CGFloat = 21.0 / 9.0
        let fourAspects: [CGFloat] = [landscapeAspect, portraitAspect, panoramicAspect, panoramicAspect]
        let landscapes = PhotoLayoutMetrics(aspects: Array(repeating: landscapeAspect, count: 6),
                                             deckWidth: 252, gridWidth: 287)
        try expect(landscapes.columns == 3, "Six photos form two rows of three")
        try expect(landscapes.gridSize.height < 120,
                   "Landscape-only rows do not reserve square cells or a collapse footer")

        let four = PhotoLayoutMetrics(aspects: fourAspects,
                                      deckWidth: 252, gridWidth: 287)
        try expect(four.columns == 3, "Four photos still use the reference's three-column layout")
        try expect(abs(four.gridCards[0].midY - four.gridCards[1].midY) < 0.001,
                   "Landscape and portrait photos are vertically centered in their row")
        try expect(four.gridCards[3].minY > four.gridCards[1].maxY,
                   "The next row clears the preceding portrait without overlapping it")
        for (frame, aspect) in zip(four.gridCards, fourAspects) {
            try expect(abs(frame.width / frame.height - aspect) < 0.001,
                       "The expanded grid preserves each photo's aspect ratio")
        }

        for count in [0, 1, 2, 3, 4, 6, 30] {
            let aspects: [CGFloat] = (0..<count).map {
                $0.isMultiple(of: 2) ? landscapeAspect : portraitAspect
            }
            let metrics = PhotoLayoutMetrics(aspects: aspects,
                                              deckWidth: 252, gridWidth: 287)
            try expect(metrics.gridCards.count == count && metrics.deckCards.count == count,
                       "Every selected photo has one position, including selections larger than five")
            for frame in metrics.gridCards {
                try expect(frame.minX >= 0 && frame.maxX <= metrics.gridSize.width + 0.001
                           && frame.minY >= 0 && frame.maxY <= metrics.gridSize.height + 0.001,
                           "Every photo stays inside the message's declared layout bounds")
            }
            if count > 0 {
                for front in 0..<count {
                    let depths = (0..<count).map { PhotoLayoutMetrics.depth(of: $0, front: front, count: count) }
                    try expect(Set(depths) == Set(0..<count) && depths[front] == 0,
                               "Cycling the cover keeps every photo in a stable, unique layer")
                }
            }
        }

        let malformed = PhotoLayoutMetrics(aspects: [0, -1, .nan, .infinity, 0.001, 1000],
                                           deckWidth: 130, gridWidth: 180)
        try expect(malformed.gridSize.height.isFinite && malformed.deckSize.height.isFinite,
                   "Invalid or extreme image metadata cannot produce an infinite message layout")
        try expect(malformed.gridCards.allSatisfy { $0.width > 0 && $0.height > 0 },
                   "Very narrow panoramas and malformed metadata still have finite positive bounds")
    }
}
