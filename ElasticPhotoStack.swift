import SwiftUI
import UIKit
import QuartzCore
import CoreImage

// UIKit owns the moving cards. SwiftUI receives only an expand/collapse or cover
// selection event, never a stream of drag updates that would relayout the chat.
struct ElasticPhotoDeck: UIViewRepresentable {
    let media: LocalMediaFiles
    let keys: [String]
    let width: CGFloat
    let expanded: Bool
    let frontIndex: Int
    let reduceMotion: Bool
    let onExpand: () -> Void
    let onSelect: (Int) -> Void
    let onPreview: (Int) -> Void

    func makeUIView(context: Context) -> ElasticPhotoDeckView { ElasticPhotoDeckView() }
    func updateUIView(_ view: ElasticPhotoDeckView, context: Context) {
        view.onExpand = onExpand; view.onSelect = onSelect; view.onPreview = onPreview
        view.configure(media: media, keys: keys, width: width, expanded: expanded,
                       frontIndex: frontIndex, reduceMotion: reduceMotion)
    }
    static func dismantleUIView(_ view: ElasticPhotoDeckView, coordinator: ()) { view.stopAnimating() }
}

private final class DeckImages {
    let sharp: UIImage
    let blurred: UIImage?
    init(sharp: UIImage, blurred: UIImage?) { self.sharp = sharp; self.blurred = blurred }
}

// Decode and blur only on a worker queue. The animation loop changes transforms
// and cached-image opacity; it never opens a file or runs a blur filter.
private final class DeckImageCache: @unchecked Sendable {
    static let shared = DeckImageCache()
    let queue = DispatchQueue(label: "WeChat26Demo.photo-deck", qos: .userInitiated)
    private let cache = NSCache<NSString, DeckImages>()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private init() { cache.totalCostLimit = 40 * 1024 * 1024 }

    func cached(_ key: String, pixels: Int) -> DeckImages? {
        cache.object(forKey: "\(key)@\(pixels)" as NSString)
    }
    func prepare(_ key: String, pixels: Int, media: LocalMediaFiles) -> DeckImages? {
        if let cached = cached(key, pixels: pixels) { return cached }
        guard let sharp = media.image(key, maxPixel: pixels) else { return nil }
        var blurred: UIImage?
        if let cg = sharp.cgImage {
            let source = CIImage(cgImage: cg)
            let radius = max(2, Double(max(cg.width, cg.height)) * 0.008)
            let output = source.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            if let result = context.createCGImage(output, from: source.extent) { blurred = UIImage(cgImage: result) }
        }
        let images = DeckImages(sharp: sharp, blurred: blurred)
        let cost = sharp.cgImage.map { $0.bytesPerRow * $0.height * 2 } ?? 0
        cache.setObject(images, forKey: "\(key)@\(pixels)" as NSString, cost: cost)
        return images
    }
}

private final class DeckCardView: UIView {
    let index: Int
    let key: String
    let sharp = UIImageView()
    let blurred = UIImageView()
    var requestedPixels = 0
    var x = StackSpring(), y = StackSpring(), angle = StackSpring()
    var scale = StackSpring(1), opacity = StackSpring(), blur = StackSpring()
    var dragX = StackSpring(), dragY = StackSpring(), tilt = StackSpring()

    init(index: Int, key: String) {
        self.index = index; self.key = key
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        for image in [sharp, blurred] {
            image.contentMode = .scaleAspectFill
            image.clipsToBounds = true
            image.layer.cornerRadius = 14
            image.layer.cornerCurve = .continuous
            addSubview(image)
        }
        sharp.layer.borderWidth = 0.5
        sharp.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSize(_ size: CGSize) {
        guard bounds.size != size else { return }
        bounds.size = size
        sharp.frame = bounds; blurred.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
    }
    func setImages(_ images: DeckImages) { sharp.image = images.sharp; blurred.image = images.blurred }
    func advance(_ dt: Double, reduceMotion: Bool) {
        if reduceMotion {
            x.snap(); y.snap(); angle.snap(); scale.snap(); opacity.snap(); blur.snap()
        } else {
            x.advance(dt); y.advance(dt); angle.advance(dt)
            scale.advance(dt); opacity.advance(dt, damping: 1); blur.advance(dt, damping: 1)
        }
    }
    func snap() {
        x.snap(); y.snap(); angle.snap(); scale.snap(); opacity.snap(); blur.snap()
        dragX.target = 0; dragY.target = 0; tilt.target = 0
        dragX.snap(); dragY.snap(); tilt.snap()
    }
    var settled: Bool {
        x.isSettled() && y.isSettled() && angle.isSettled(0.0005) && scale.isSettled(0.0005)
            && opacity.isSettled(0.002) && blur.isSettled(0.002)
            && dragX.isSettled() && dragY.isSettled() && tilt.isSettled(0.0005)
    }
    func render() {
        center = CGPoint(x: x.value + dragX.value, y: y.value + dragY.value)
        transform = CGAffineTransform(rotationAngle: angle.value + tilt.value)
            .scaledBy(x: max(0.01, scale.value), y: max(0.01, scale.value))
        alpha = min(1, max(0, opacity.value))
        blurred.alpha = min(1, max(0, blur.value))
    }
}

final class ElasticPhotoDeckView: UIView, UIGestureRecognizerDelegate {
    var onExpand: () -> Void = {}
    var onSelect: (Int) -> Void = { _ in }
    var onPreview: (Int) -> Void = { _ in }
    private var media: LocalMediaFiles?
    private var keys: [String] = []
    private var cards: [Int: DeckCardView] = [:]
    private var ordered: [DeckCardView] = []
    private var deckWidth: CGFloat = 0
    private var deckHeight: CGFloat = 0
    private var expanded = false
    private var front = 0
    private var reduceMotion = false
    private var dragging = false
    private var touchOffset = CGPoint.zero
    private var generation = 0
    private var wasAttached = false
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.require(toFail: pan)
        addGestureRecognizer(tap)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.45
        addGestureRecognizer(hold)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(media: LocalMediaFiles, keys: [String], width: CGFloat,
                   expanded: Bool, frontIndex: Int, reduceMotion: Bool) {
        let changedKeys = self.keys != keys
        let nextFront = keys.isEmpty ? 0 : (frontIndex % keys.count + keys.count) % keys.count
        guard changedKeys || deckWidth != width || self.expanded != expanded
            || front != nextFront || self.reduceMotion != reduceMotion else { return }
        let initial = self.keys.isEmpty || changedKeys
        if changedKeys {
            generation += 1
            for card in cards.values { card.removeFromSuperview() }
            cards.removeAll(); ordered.removeAll()
        }
        self.media = media; self.keys = keys; deckWidth = width
        self.expanded = expanded; front = nextFront; self.reduceMotion = reduceMotion
        if expanded { dragging = false; touchOffset = .zero }
        deckHeight = (keys.map { fitted(media.aspect($0)).height }.max() ?? 160) + 28
        updateTargets(initial: initial)
    }

    private func relative(_ index: Int) -> Int { (index - front + keys.count) % max(1, keys.count) }
    private func fitted(_ ratio: CGFloat) -> CGSize {
        let safeRatio = max(0.05, ratio)
        let width = min(max(1, deckWidth - 30), 224 * safeRatio)
        return CGSize(width: width, height: width / safeRatio)
    }
    private func updateTargets(initial: Bool = false) {
        guard let media, !keys.isEmpty else { return }
        let visible = expanded ? Array(keys.indices) : (0..<min(5, keys.count)).map { (front + $0) % keys.count }
        let columns = keys.count > 4 ? 3 : 2
        let side = (deckWidth - CGFloat(columns - 1) * 9) / CGFloat(columns)
        for index in visible where cards[index] == nil {
            let card = DeckCardView(index: index, key: keys[index])
            card.x = StackSpring(Double(deckWidth / 2)); card.y = StackSpring(Double(deckHeight / 2))
            card.scale = StackSpring(0.9)
            card.sharp.image = media.image(keys[index], maxPixel: 96)
            cards[index] = card
            addSubview(card)
        }
        for (index, card) in cards {
            let depth = relative(index)
            let rank = min(4, depth)
            let size = fitted(media.aspect(keys[index]))
            card.setSize(size)
            card.layer.zPosition = CGFloat(keys.count - depth)
            card.x.target = Double(expanded ? side / 2 + CGFloat(index % columns) * (side + 9)
                : deckWidth / 2 + [CGFloat(0), 6, -8, 3, -4][rank])
            card.y.target = Double(expanded ? side / 2 + CGFloat(index / columns) * (side + 9)
                : deckHeight / 2 + [CGFloat(2), -7, 3, -11, -3][rank])
            card.angle.target = expanded || reduceMotion ? 0 : [-4.0, 5.0, -10.0, 3.0, -2.0][rank] * .pi / 180
            card.scale.target = expanded ? Double(min(side / size.width, side / size.height))
                : 1 - Double(rank) * 0.022 + (dragging && depth == 0 && !reduceMotion ? 0.018 : 0)
            card.opacity.target = expanded || depth < 5 ? 1 : 0
            card.blur.target = expanded || depth == 0 ? 0 : [0.0, 0.5, 0.74, 0.9, 1.0][rank]
            if initial || reduceMotion { card.snap() }
            if visible.contains(index) { requestImages(card, pixels: expanded ? 384 : 800) }
        }
        ordered = cards.values.sorted { relative($0.index) < relative($1.index) }
        render()
        startAnimating()
    }

    private func requestImages(_ card: DeckCardView, pixels: Int) {
        guard let media, card.requestedPixels < pixels else { return }
        card.requestedPixels = pixels
        let key = card.key, revision = generation
        let cache = DeckImageCache.shared
        if let images = cache.cached(key, pixels: pixels) { card.setImages(images); return }
        cache.queue.async { [weak self, weak card] in
            let images = autoreleasepool { cache.prepare(key, pixels: pixels, media: media) }
            DispatchQueue.main.async { [weak self, weak card] in
                guard let self, let card, self.generation == revision,
                      self.cards[card.index] === card, card.requestedPixels == pixels,
                      let images else { return }
                card.setImages(images)
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAnimating()
            dragging = false; touchOffset = .zero
            if wasAttached {
                generation += 1
                for card in cards.values {
                    card.sharp.image = nil; card.blurred.image = nil; card.requestedPixels = 0
                }
            }
        } else {
            wasAttached = true
            updateTargets()
        }
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        ordered.contains { card in card.alpha > 0.05 && card.bounds.contains(card.convert(point, from: self)) }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan else { return true }
        let velocity = pan.velocity(in: self)
        return !expanded && keys.count > 1 && abs(velocity.x) > abs(velocity.y) * 1.2
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Let the enclosing chat retain vertical scrolling and interactive dismissal.
        other.view is UIScrollView
    }
    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began, .changed:
            let began = !dragging
            dragging = true
            touchOffset = CGPoint(x: min(deckWidth * 0.45, max(-deckWidth * 0.45, translation.x)) * 0.62,
                                  y: min(32, max(-32, translation.y)) * 0.35)
            if began { updateTargets() }
            startAnimating()
        case .ended, .cancelled, .failed:
            dragging = false; touchOffset = .zero
            let velocity = gesture.velocity(in: self).x
            let deliberateSwipe = abs(translation.x) > deckWidth * 0.30
                || (abs(translation.x) > deckWidth * 0.18 && abs(velocity) > 650)
            if gesture.state == .ended && deliberateSwipe {
                front = (front + (translation.x < 0 ? 1 : keys.count - 1)) % keys.count
                onSelect(front)
            }
            updateTargets()
        default: break
        }
    }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        if !expanded { onExpand(); return }
        let point = gesture.location(in: self)
        if let card = ordered.first(where: { $0.bounds.contains($0.convert(point, from: self)) }) { onSelect(card.index) }
    }
    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: self)
        let index = expanded ? ordered.first { $0.bounds.contains($0.convert(point, from: self)) }?.index : front
        if let index { onPreview(index) }
    }

    @MainActor private final class DisplayLinkTarget: NSObject {
        weak var owner: ElasticPhotoDeckView?
        init(_ owner: ElasticPhotoDeckView) { self.owner = owner }
        @objc func tick(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.tick(link)
        }
    }
    private func startAnimating() {
        guard displayLink == nil, window != nil else { return }
        let link = CADisplayLink(target: DisplayLinkTarget(self), selector: #selector(DisplayLinkTarget.tick(_:)))
        let fps = Float(window?.windowScene?.screen.maximumFramesPerSecond ?? 60)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: fps, preferred: fps)
        lastTimestamp = 0
        displayLink = link
        link.add(to: .main, forMode: .common)
    }
    func stopAnimating() {
        displayLink?.invalidate(); displayLink = nil; lastTimestamp = 0
    }
    private func tick(_ link: CADisplayLink) {
        let elapsed = lastTimestamp == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        let dt = min(1.0 / 20, max(1.0 / 240, elapsed))
        // Substeps keep the coupled chain equally smooth at 60 and 120 Hz.
        let steps = max(1, Int(ceil(dt * 120)))
        for _ in 0..<steps { advance(dt / Double(steps)) }
        render()
        if !dragging && ordered.allSatisfy(\.settled) {
            for card in ordered { card.snap() }
            render()
            let retired = cards.keys.filter { !expanded && relative($0) >= 5 }
            for index in retired { cards.removeValue(forKey: index)?.removeFromSuperview() }
            ordered.removeAll { cards[$0.index] == nil }
            stopAnimating()
        }
    }
    private func advance(_ dt: Double) {
        var above: DeckCardView?
        for card in ordered {
            let depth = relative(card.index)
            if !expanded && depth < 5 {
                card.dragX.target = depth == 0 ? Double(touchOffset.x) : (above?.dragX.value ?? 0) * 0.80
                card.dragY.target = depth == 0 ? Double(touchOffset.y) : (above?.dragY.value ?? 0) * 0.78
                card.tilt.target = depth == 0 ? Double(touchOffset.x) * 0.0015 : (above?.tilt.value ?? 0) * 0.90
            } else { card.dragX.target = 0; card.dragY.target = 0; card.tilt.target = 0 }
            if reduceMotion {
                if depth > 0 { card.dragX.target = 0; card.dragY.target = 0 }
                card.tilt.target = 0
                card.dragX.snap(); card.dragY.snap(); card.tilt.snap()
            } else {
                let frequency = depth == 0 ? (dragging ? 14.0 : 6.5) : max(3.6, 6.2 - Double(depth) * 0.6)
                let damping = depth == 0 ? (dragging ? 0.9 : 0.64) : 0.56
                card.dragX.advance(dt, frequency: frequency, damping: damping)
                card.dragY.advance(dt, frequency: frequency, damping: damping)
                card.tilt.advance(dt, frequency: frequency, damping: damping)
            }
            card.advance(dt, reduceMotion: reduceMotion)
            above = card
        }
    }
    private func render() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for card in ordered { card.render() }
        CATransaction.commit()
    }
}
