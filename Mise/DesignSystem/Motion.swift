import SwiftUI
import UIKit
import CoreHaptics

// Motion + touch vocabulary. Every animation in the app pulls from these four
// springs so the whole surface moves like one material.
enum Motion {
    /// Chrome and small state changes.
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Cards entering, embeds appearing — a touch of overshoot.
    static let arrive = Animation.spring(response: 0.5, dampingFraction: 0.74)
    /// The big thread ↔ timeline zoom.
    static let zoom = Animation.spring(response: 0.55, dampingFraction: 0.82)
    /// Playful bounce for the calorie ring and reactions.
    static let bounce = Animation.spring(response: 0.42, dampingFraction: 0.58)
}

/// One shared haptics brain. Cheap taps use UIKit generators; signature moments
/// (a meal landing in the log) get a composed CoreHaptics pattern.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var engine: CHHapticEngine?

    private init() {
        light.prepare(); soft.prepare(); rigid.prepare()
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    /// Page snaps, button taps.
    func tick() { light.impactOccurred(intensity: 0.7) }
    /// Gesture thresholds crossed (zoom commit).
    func thud() { rigid.impactOccurred(intensity: 0.9) }
    /// Streaming text finished.
    func settle() { soft.impactOccurred(intensity: 0.5) }

    /// "Plated" — a two-beat flourish when food lands in the log.
    func plated() {
        guard let engine else { rigid.impactOccurred(); return }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.55),
                .init(parameterID: .hapticSharpness, value: 0.9),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.35),
            ], relativeTime: 0.09),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.28),
                .init(parameterID: .hapticSharpness, value: 0.1),
            ], relativeTime: 0.12, duration: 0.22),
        ]
        if let pattern = try? CHHapticPattern(events: events, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        } else {
            rigid.impactOccurred()
        }
    }
}
