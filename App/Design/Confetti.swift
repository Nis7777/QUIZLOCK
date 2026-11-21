import SwiftUI

/// Coral / yellow / green / purple rounded confetti bursting up and falling with gravity (1.2s),
/// drawn in a Canvas (`drawingGroup`). Nothing is drawn when Reduce Motion is on.
struct ConfettiView: View {
    var count = 70
    /// Where the burst starts, as a fraction of the view (default: upper middle).
    var origin = UnitPoint(x: 0.5, y: 0.35)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private struct Piece {
        let angle: Double, speed: Double, spin: Double, size: Double, color: Color, round: Bool, delay: Double
    }

    private static let duration: Double = 1.2

    @State private var pieces: [Piece] = {
        let colors: [Color] = [.brand, Color(hex: 0xFFC83D), Color(hex: 0x34C759), Color(hex: 0xAF52DE)]
        return (0..<90).map { _ in
            Piece(angle: .random(in: -.pi * 0.95 ... -.pi * 0.05), speed: .random(in: 420...900),
                  spin: .random(in: -9...9), size: .random(in: 7...12),
                  color: colors.randomElement() ?? .brand, round: Bool.random(), delay: .random(in: 0...0.08))
        }
    }()

    var body: some View {
        if reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    guard t < Self.duration + 0.1 else { return }
                    let ox = origin.x * size.width, oy = origin.y * size.height
                    let gravity = 1500.0
                    for p in pieces.prefix(count) {
                        let lt = t - p.delay
                        guard lt > 0 else { continue }
                        let x = ox + cos(p.angle) * p.speed * lt
                        let y = oy + sin(p.angle) * p.speed * lt + 0.5 * gravity * lt * lt
                        var ctx = context
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: .radians(lt * p.spin))
                        ctx.opacity = max(0, min(1, (Self.duration - lt) / 0.3))
                        let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size * (p.round ? 1 : 0.55))
                        let path = p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
                        ctx.fill(path, with: .color(p.color))
                    }
                }
            }
            .drawingGroup()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}

extension View {
    /// Overlays a one-shot confetti burst (+ a success haptic) while `isActive` is true.
    func confetti(_ isActive: Bool, origin: UnitPoint = UnitPoint(x: 0.5, y: 0.35), haptic: Bool = true) -> some View {
        overlay {
            if isActive { ConfettiView(origin: origin).ignoresSafeArea() }
        }
        .sensoryFeedback(.success, trigger: isActive) { _, now in haptic && now }
    }
}
