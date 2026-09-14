import CoreGraphics

enum PhotoGestureIntent: Equatable {
    case undecided, photo, scroll
    static let threshold: CGFloat = 18
    static func classify(_ offset: CGSize) -> Self {
        let x = abs(offset.width), y = abs(offset.height)
        guard x.isFinite, y.isFinite else { return .scroll }
        if y >= 12 && y >= x * 1.15 { return .scroll }
        if x >= threshold && x >= y * 1.8 { return .photo }
        if x * x + y * y >= 30 * 30 { return .scroll }
        return .undecided
    }
}
