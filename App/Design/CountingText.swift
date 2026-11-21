import SwiftUI

/// A number that counts smoothly. `value` is the view's `animatableData`, so SwiftUI interpolates it every
/// frame (60/120 fps) along whatever animation changed it. There are no timers or stepped values.
///
/// Usage: keep a `CountUpState` on the screen, show `CountingText(value: target * count.progress, …)` and
/// attach `.countUp($count)` once. Anything else tied to `count.progress` (bars, arcs) moves in perfect sync
/// because it rides the same transaction and curve.
///
///     @State private var count = CountUpState()
///     CountingText(value: years * count.progress, final: years, format: CountingText.decimal(1), landed: count.landed)
///         .countUp($count, after: CountUpState.onboardingEntrance, feedback: .impact(weight: .heavy))
struct CountingText: View, Animatable {
    /// The number shown right now (animated).
    var value: Double
    /// The number it lands on: reserves the width so nothing around it shifts while counting.
    let final: Double
    let format: (Double) -> String
    /// Flips to true when the count lands: a tiny 1.0 → 1.06 → 1.0 pop.
    var landed = false

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        ZStack {
            Text(verbatim: format(final)).hidden()
            Text(verbatim: format(value))
        }
        .monospacedDigit()
        .lineLimit(1)
        .modifier(LandingPop(trigger: landed))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: format(final)))
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: Formatters

    /// "12.4" (fixed fraction digits).
    static func decimal(_ digits: Int) -> (Double) -> String {
        { $0.formatted(.number.precision(.fractionLength(digits))) }
    }

    /// "42".
    static let integer: (Double) -> String = { Int($0.rounded()).formatted() }

    /// "67%".
    static let percent: (Double) -> String = { "\(Int($0.rounded()))%" }

    // MARK: Timing

    /// 0 → final in 1.6s, fast start, gentle settle, no overshoot.
    static func curve(duration: Double = 1.6) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}

/// 1.0 → 1.06 → 1.0 with Motion.bouncy when `trigger` becomes true (skipped with Reduce Motion).
private struct LandingPop: ViewModifier {
    let trigger: Bool
    @State private var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, landed in
                guard landed, !reduceMotion else { return }
                withAnimation(Motion.snappy) { scale = 1.06 }
                withAnimation(Motion.bouncy.delay(0.12)) { scale = 1 }
            }
    }
}

/// Drives one or more CountingTexts (and anything else bound to `progress`).
struct CountUpState: Equatable {
    /// 0 → 1 along `CountingText.curve`.
    var progress: Double = 0
    var landed = false

    /// Onboarding screens slide in with Motion.smooth (~0.5s) plus a staggered appear.
    static let onboardingEntrance: Double = 0.55
}

private struct CountUpModifier: ViewModifier {
    @Binding var state: CountUpState
    let entrance: Double
    let duration: Double
    let feedback: SensoryFeedback?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .sensoryFeedback(feedback ?? .success, trigger: state.landed) { _, landed in feedback != nil && landed }
            .task {
                guard !state.landed else { return }
                if reduceMotion {
                    // Final value straight away, with a simple fade.
                    opacity = 0
                    state.progress = 1
                    withAnimation(.easeOut(duration: 0.3)) { opacity = 1 }
                    state.landed = true
                    return
                }
                // Start 0.35s after the screen's entrance animation has finished.
                try? await Task.sleep(nanoseconds: UInt64((entrance + 0.35) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(CountingText.curve(duration: duration)) { state.progress = 1 }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                state.landed = true
            }
    }
}

extension View {
    /// Counts `state.progress` from 0 to 1 once, after `entrance` seconds + 0.35s, then sets `landed`
    /// (pop + one haptic). Pass `feedback: nil` for no haptic.
    func countUp(_ state: Binding<CountUpState>, after entrance: Double = 0, duration: Double = 1.6,
                 feedback: SensoryFeedback? = .success) -> some View {
        modifier(CountUpModifier(state: state, entrance: entrance, duration: duration, feedback: feedback))
    }
}
