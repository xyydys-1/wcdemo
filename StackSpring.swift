import Foundation

// Closed-form damped spring. Time, not frame count, controls the response so a
// ProMotion display and a 60 Hz display have the same settling time.
struct StackSpring {
    var value: Double
    var target: Double
    var velocity = 0.0

    init(_ value: Double = 0) { self.value = value; self.target = value }

    mutating func advance(_ dt: Double, frequency: Double = 5.8, damping: Double = 0.76) {
        guard dt > 0 else { return }
        let omega = 2 * Double.pi * frequency
        let displacement = value - target
        let decay = exp(-damping * omega * dt)
        if damping < 1 {
            let damped = omega * sqrt(1 - damping * damping)
            let sine = sin(damped * dt)
            let cosine = cos(damped * dt)
            value = target + decay * (displacement * cosine + (velocity + damping * omega * displacement) / damped * sine)
            velocity = decay * (velocity * cosine - (omega * omega * displacement + damping * omega * velocity) / damped * sine)
        } else {
            let coefficient = velocity + omega * displacement
            value = target + exp(-omega * dt) * (displacement + coefficient * dt)
            velocity = exp(-omega * dt) * (velocity - omega * coefficient * dt)
        }
    }

    func isSettled(_ tolerance: Double = 0.01) -> Bool {
        abs(value - target) < tolerance && abs(velocity) < tolerance * 20
    }
    mutating func snap() { value = target; velocity = 0 }
}
