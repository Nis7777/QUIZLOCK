import SwiftUI

/// Motion tokens (MOTION.md). Use only these for animation.
enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82) // taps, toggles, selections
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.86) // screen content, cards
    static let bouncy = Animation.spring(response: 0.50, dampingFraction: 0.62) // celebrations, mascot, success
    static let gentle = Animation.spring(response: 0.70, dampingFraction: 0.90) // big layout changes, paywall
    static let stagger: Double = 0.06                                              // delay between list items

    /// `animation`, or a quick fade when Reduce Motion is on.
    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : animation
    }
}

// MARK: - Pressable

/// Scale 0.96 + opacity 0.9 on press (Motion.snappy) and a light haptic. Use for every button and tappable card.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

// MARK: - Staggered appear

/// Starts at opacity 0, y +18, blur 4, then springs in after `index × Motion.stagger`.
/// With Reduce Motion: a plain fade.
struct StaggeredAppear: ViewModifier {
    let index: Int
    var baseDelay: Double = 0.05
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .blur(radius: shown || reduceMotion ? 0 : 4)
            .onAppear {
                let delay = baseDelay + Double(index) * Motion.stagger
                withAnimation(Motion.respecting(reduceMotion, Motion.smooth).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int, baseDelay: Double = 0.05) -> some View {
        modifier(StaggeredAppear(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Shimmer

/// A soft light sweep across the view every 3s (main CTAs). Off with Reduce Motion.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0)
                    let progress = min(1, t / 0.9) // sweep takes 0.9s, then rests
                    GeometryReader { geo in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.45), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.35)
                            .rotationEffect(.degrees(18))
                            .offset(x: -geo.size.width * 0.5 + progress * geo.size.width * 1.6)
                            .opacity(t < 0.9 ? 1 : 0)
                    }
                }
                .allowsHitTesting(false)
                .blendMode(.plusLighter)
            }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Shake (keyframes 0, −10, 10, −6, 6, 0 over 0.35s)

struct KeyframeShake: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-10, duration: 0.07)
                    LinearKeyframe(10, duration: 0.07)
                    LinearKeyframe(-6, duration: 0.07)
                    LinearKeyframe(6, duration: 0.07)
                    LinearKeyframe(0, duration: 0.07)
                }
            }
        }
    }
}
