import SwiftUI
import UIKit

// Reject vertical intent before recognition. Filtering a SwiftUI DragGesture's
// onChanged is too late: it may already have prevented the ScrollView's pan.
struct PhotoPanGesture: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let changed: (CGSize) -> Void
    let ended: (CGSize, CGSize) -> Void
    let cancelled: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // The containing vertical scroll view remains eligible throughout.
            other is UIPanGestureRecognizer
        }
    }
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        pan.isEnabled = enabled
        return pan
    }
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = enabled
    }
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let offset = recognizer.translation(in: nil)
        let velocity = recognizer.velocity(in: nil)
        let translation = CGSize(width: offset.x, height: offset.y)
        switch recognizer.state {
        case .began, .changed: changed(translation)
        case .ended: ended(translation, CGSize(width: velocity.x, height: velocity.y))
        case .cancelled, .failed: cancelled()
        default: break
        }
    }
}
