import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

final class PhotoIntentRecognizer: UIGestureRecognizer {
    private(set) var translation = CGSize.zero
    private(set) var velocity = CGSize.zero
    private weak var trackedTouch: UITouch?
    private var origin = CGPoint.zero
    private var dragOrigin = CGPoint.zero
    private var previous = CGPoint.zero
    private var previousTime: TimeInterval = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first else { state = .failed; return }
        trackedTouch = touch
        origin = touch.location(in: view)
        previous = origin
        previousTime = touch.timestamp
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        let point = sample(touch)
        if state == .possible {
            let offset = CGSize(width: point.x-origin.x, height: point.y-origin.y)
            switch PhotoGestureIntent.classify(offset) {
            case .undecided: return
            case .scroll: state = .failed
            case .photo:
                let sign: CGFloat = offset.width < 0 ? -1 : 1
                dragOrigin = CGPoint(x: origin.x + sign * PhotoGestureIntent.threshold, y: point.y)
                translation = CGSize(width: point.x-dragOrigin.x, height: 0)
                state = .began
            }
        } else if state == .began || state == .changed {
            translation = CGSize(width: point.x-dragOrigin.x, height: point.y-dragOrigin.y)
            state = .changed
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        if state == .began || state == .changed {
            let point = sample(touch)
            translation = CGSize(width: point.x-dragOrigin.x, height: point.y-dragOrigin.y)
            state = .ended
        } else { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = (state == .began || state == .changed) ? .cancelled : .failed
    }
    override func reset() {
        super.reset(); trackedTouch = nil; translation = .zero; velocity = .zero; origin = .zero; dragOrigin = .zero; previous = .zero; previousTime = 0
    }
    private func sample(_ touch: UITouch) -> CGPoint {
        let p = touch.location(in: view)
        let dt = CGFloat(max(0.001, touch.timestamp - previousTime))
        velocity = CGSize(width: (p.x-previous.x)/dt, height: (p.y-previous.y)/dt)
        previous = p; previousTime = touch.timestamp
        return p
    }
}

@available(iOS 26.0, *)
struct PhotoPanGesture: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let changed: (CGSize) -> Void
    let ended: (CGSize, CGSize) -> Void
    let cancelled: () -> Void
    func makeUIGestureRecognizer(context: Context) -> PhotoIntentRecognizer {
        let r = PhotoIntentRecognizer(); r.isEnabled = enabled; r.cancelsTouchesInView = true; return r
    }
    func updateUIGestureRecognizer(_ recognizer: PhotoIntentRecognizer, context: Context) { recognizer.isEnabled = enabled }
    func handleUIGestureRecognizerAction(_ recognizer: PhotoIntentRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: changed(recognizer.translation)
        case .ended: ended(recognizer.translation, recognizer.velocity)
        case .cancelled, .failed: cancelled()
        default: break
        }
    }
}
