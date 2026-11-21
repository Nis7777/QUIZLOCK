import SwiftUI
import UIKit

/// Lockie's expressions (Assets: mascot_<name>). Missing art falls back to `mascot_pointing`.
enum MascotExpression: String, CaseIterable, Equatable {
    case wave, happy, worried, sad, thinking, clipboard, celebrate, calm, pointing

    var assetName: String { "mascot_\(rawValue)" }

    var image: UIImage? {
        UIImage(named: assetName) ?? UIImage(named: MascotExpression.pointing.assetName)
    }
}

/// Lockie with an idle "breathing" loop (scale 1 ↔ 1.02 + ±2° wobble), a bouncy pop-in from 0.6, and a
/// cross-fade + squash-and-stretch (0.92 → 1.04 → 1) with a light haptic whenever the expression changes.
struct LockieView: View {
    let expression: MascotExpression
    var size: CGFloat = 200
    var breathing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            if let image = expression.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .id(expression)
                    .transition(.opacity)
            } else {
                Image(systemName: "lock.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.brand)
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: expression)
        .modifier(Squash(trigger: expression, enabled: !reduceMotion))
        .modifier(Breathing(enabled: breathing && !reduceMotion))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .sensoryFeedback(.impact(weight: .light), trigger: expression)
        .onAppear {
            withAnimation(Motion.respecting(reduceMotion, Motion.bouncy)) { appeared = true }
        }
        .accessibilityLabel(Text("Lockie"))
    }
}

/// 0.92 → 1.04 → 1.0 on every expression change.
private struct Squash: ViewModifier {
    let trigger: MascotExpression
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(x: 2 - scale, y: scale, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(0.92, duration: 0.09, spring: .snappy)
                    SpringKeyframe(1.04, duration: 0.16, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                }
            }
        } else {
            content
        }
    }
}

/// Gentle idle loop: scale 1.0 ↔ 1.02 with a ±2° wobble, 2.4s per cycle.
private struct Breathing: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.phaseAnimator([0.0, 1.0, 0.0, -1.0]) { view, phase in
                view
                    .scaleEffect(1 + 0.02 * abs(phase), anchor: .bottom)
                    .rotationEffect(.degrees(2 * phase), anchor: .bottom)
            } animation: { _ in
                .spring(duration: 0.6, bounce: 0)
            }
        } else {
            content
        }
    }
}

// MARK: - Shared mascot between onboarding screens

/// A screen reserves a spot for Lockie with `MascotSlot`; the onboarding container draws ONE Lockie at
/// that spot, so it glides between consecutive screens instead of disappearing and reappearing.
struct MascotSlotEntry {
    let expression: MascotExpression
    let anchor: Anchor<CGRect>
}

struct MascotSlotKey: PreferenceKey {
    static let defaultValue: [MascotSlotEntry] = []
    static func reduce(value: inout [MascotSlotEntry], nextValue: () -> [MascotSlotEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// Empty space of `size` where the container's Lockie appears.
struct MascotSlot: View {
    let expression: MascotExpression
    var size: CGFloat = 200

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .anchorPreference(key: MascotSlotKey.self, value: .bounds) { [MascotSlotEntry(expression: expression, anchor: $0)] }
            .accessibilityElement()
            .accessibilityLabel(Text("Lockie"))
    }
}

/// Draws the shared Lockie at the newest slot. Moves with Motion.smooth when the slot moves.
struct SharedMascotOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(MascotSlotKey.self) { slots in
            GeometryReader { proxy in
                if let slot = slots.last {
                    let rect = proxy[slot.anchor]
                    LockieView(expression: slot.expression, size: max(rect.width, 1))
                        .position(x: rect.midX, y: rect.midY)
                        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: rect)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
