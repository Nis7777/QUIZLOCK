import SwiftUI

/// Coral-themed confetti burst. Shows nothing when Reduce Motion is on.
struct ConfettiView: View {
    var count = 70
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private struct Piece {
        let x: Double, delay: Double, speed: Double, spin: Double, drift: Double, size: Double, color: Color, circle: Bool
    }

    @State private var pieces: [Piece] = {
        let colors: [Color] = [.brand, .brandDeep, Color(hex: 0xFFC145), Color(hex: 0x6AAA64), Color(hex: 0x4CC3FF), .white]
        return (0..<70).map { _ in
            Piece(x: .random(in: 0...1), delay: .random(in: 0...0.35), speed: .random(in: 0.55...1.1),
                  spin: .random(in: -6...6), drift: .random(in: -60...60), size: .random(in: 6...11),
                  color: colors.randomElement() ?? .brand, circle: Bool.random())
        }
    }()

    var body: some View {
        if reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    for p in pieces.prefix(count) {
                        let lt = t - p.delay
                        guard lt > 0 else { continue }
                        let y = -20 + lt * p.speed * size.height * 0.9
                        guard y < size.height + 20 else { continue }
                        let x = p.x * size.width + sin(lt * 3 + p.spin) * p.drift
                        var ctx = context
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: .radians(lt * p.spin))
                        let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size * (p.circle ? 1 : 0.5))
                        ctx.opacity = max(0, 1 - lt / 2.6)
                        ctx.fill(p.circle ? Path(ellipseIn: rect) : Path(rect), with: .color(p.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}

extension View {
    /// Overlays a one-shot confetti burst while `isActive` is true.
    func confetti(_ isActive: Bool) -> some View {
        overlay {
            if isActive { ConfettiView().ignoresSafeArea() }
        }
    }
}
