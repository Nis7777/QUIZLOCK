import Charts
import SwiftUI

// MARK: - Chapter 5: The turn

/// 5.1 "Don't worry, {name}. That's about to change."
struct TurnIntroView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        OnboardingPage {
            VStack(spacing: 18) {
                MascotSlot(expression: .happy, size: 230)
                    .padding(.top, 20)
                Text("Don't worry, \(model.friendlyName). That's about to change.")
                    .appFont(32, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppear(1)
            }
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
    }
}

/// 5.2 Reality check: "At this rate, you'll spend X years of your life scrolling."
/// One choreographed reveal: the title fades in → the number (the hero) rolls up over 1.2s and lands
/// with a 1.0 → 1.08 → 1.0 bump and a medium haptic → the bars grow → the footer fades in.
/// Everything is computed once before it starts; the number changes ~12 times (each a rolling digit
/// transition), the bar is one trim animation, and nothing updates per frame from code.
struct RealityCheckView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Stage: Int, Comparable {
        case start, title, counting, landed, bars, footer
        static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }
    }

    /// Precomputed before the screen animates.
    @State private var years: Double = 0
    @State private var fraction: Double = 0
    @State private var shown: Double = 0
    @State private var stage = Stage.start
    @State private var landTick = 0

    private static let lifeLeft = 80 - 29.5
    private static let format = CountingText.decimal(1)

    var body: some View {
        OnboardingPage {
            VStack(spacing: 14) {
                MascotSlot(expression: .sad, size: 170)
                    .padding(.top, 6)
                Text("At this rate, you'll spend")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .modifier(Reveal(on: stage >= .title, reduceMotion: reduceMotion))
                ZStack {
                    Text(verbatim: Self.format(years)).hidden()   // reserves the final width: nothing shifts
                    Text(verbatim: Self.format(shown))
                        .contentTransition(.numericText(value: shown))
                }
                .appFont(84, .black, design: .rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color(hex: 0xFF3B30))
                .keyframeAnimator(initialValue: 1.0, trigger: landTick) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.08, duration: 0.14, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                }
                .modifier(Reveal(on: stage >= .counting, reduceMotion: reduceMotion))
                Text("years of your life scrolling.")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .modifier(Reveal(on: stage >= .counting, reduceMotion: reduceMotion))
                VStack(spacing: 10) {
                    ComparisonBar(title: "Your years until 80", fraction: stage >= .bars ? 1 : 0,
                                  color: Color.textSecondary.opacity(0.3))
                    ComparisonBar(title: "Spent scrolling", fraction: stage >= .bars ? fraction : 0,
                                  color: Color(hex: 0xFF3B30))
                }
                .padding(.top, 8)
                .modifier(Reveal(on: stage >= .bars, reduceMotion: reduceMotion))
                Text("Based on your daily scrolling time, until age 80.")
                    .appFont(14)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 4)
                    .modifier(Reveal(on: stage >= .footer, reduceMotion: reduceMotion))
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("At this rate, you'll spend \(Self.format(years)) years of your life scrolling."))
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
                .opacity(stage >= .footer ? 1 : 0)
                .allowsHitTesting(stage >= .footer)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: landTick)
        .task { await play() }
    }

    @MainActor
    private func play() async {
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        // Computed once, before anything moves.
        years = model.profile.yearsOnPhone
        fraction = min(1, years / Self.lifeLeft)
        if reduceMotion {
            shown = years
            withAnimation(.easeOut(duration: 0.3)) { stage = .footer }
            return
        }
        // Let the screen's push finish first.
        await wait(0.3)
        withAnimation(Motion.smooth) { stage = .title }
        await wait(0.3)
        withAnimation(Motion.smooth) { stage = .counting }
        // Count up over 1.2s, ease-out: big steps first, small ones as it lands. Each step rolls its digits.
        let steps = 12
        for i in 1...steps {
            await wait(0.1)
            guard !Task.isCancelled else { return }
            let p = Double(i) / Double(steps)
            let eased = 1 - pow(1 - p, 3)
            let value = i == steps ? years : (years * eased * 10).rounded() / 10
            withAnimation(.snappy(duration: 0.18)) { shown = value }
        }
        stage = .landed
        landTick += 1                       // bump + medium haptic
        await wait(0.35)
        withAnimation(.easeOut(duration: 0.2)) { stage = .bars }
        await wait(0.05)
        // The bars grow on their own single animation (see ComparisonBar).
        await wait(0.7)
        withAnimation(.easeOut(duration: 0.35)) { stage = .footer }
    }
}

/// Fades and rises 12pt into place when `on` turns true (opacity only with Reduce Motion).
private struct Reveal: ViewModifier {
    let on: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .offset(y: on || reduceMotion ? 0 : Motion.staggerRise)
    }
}

/// 5.3 "With Lockie, you could get back Y years." (Y = 50% of X). Counts up in coral, the bar grows in
/// sync, and light confetti lands with the number.
struct GetBackView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @State private var count = CountUpState()

    var body: some View {
        let years = model.profile.yearsOnPhone
        let back = model.profile.yearsBack
        OnboardingPage {
            VStack(spacing: 14) {
                MascotSlot(expression: .celebrate, size: 180)
                    .padding(.top, 6)
                Text("With \(Brand.appName), you could get back")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(1)
                CountingText(value: back * count.progress, final: back, format: CountingText.decimal(1),
                             landed: count.landed)
                    .appFont(76, .black, design: .rounded)
                    .foregroundStyle(Color.brand)
                    .staggeredAppear(2)
                Text("years.")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(3)
                VStack(spacing: 10) {
                    ComparisonBar(title: "Spent scrolling today", fraction: 1, color: Color.textSecondary.opacity(0.3))
                    ComparisonBar(title: "Back with \(Brand.appName)",
                                  fraction: (years > 0 ? min(1, back / years) : 0.5) * count.progress, color: Color.brand)
                }
                .padding(.top, 8)
                .staggeredAppear(4)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
        .countUp($count, after: CountUpState.onboardingEntrance, feedback: .impact(weight: .medium))   // key reveal: medium, like the reality check
        .confetti(count.landed, origin: UnitPoint(x: 0.5, y: 0.3), haptic: false)
    }
}

/// A labelled horizontal bar that grows to `fraction`. The bar is one stroked line trimmed from 0 to
/// `fraction`: a single animatable value the render server interpolates (no per-frame layout, no
/// GeometryReader). It animates on its own easeOut(1.0) whenever `fraction` changes.
struct ComparisonBar: View {
    let title: LocalizedStringKey
    let fraction: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .appFont(13, .semibold)
                .foregroundStyle(Color.textSecondary)
            ZStack {
                BarTrack().stroke(Color.textSecondary.opacity(0.08), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                BarTrack()
                    .trim(from: 0, to: max(0, min(1, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .opacity(fraction > 0 ? 1 : 0)   // a zero-length round-capped line would draw a dot
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.0), value: fraction)
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// A horizontal line through the middle, inset by half the line width so round caps stay inside.
private struct BarTrack: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.height / 2
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
        return p
    }
}

/// 5.4 Illustrative 30-day projection: coral "Scrolling" trending down, green "Living" trending up.
struct ProjectionView: View {
    let onContinue: () -> Void
    @State private var drawn: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Point: Identifiable {
        let day: Int, value: Double, series: String
        var id: String { "\(series)-\(day)" }
    }

    private static let scrolling = String(localized: "Scrolling")
    private static let living = String(localized: "Living")

    /// Smooth illustrative curves (not user data).
    private static let points: [Point] = (0...30).flatMap { d -> [Point] in
        let t = Double(d) / 30
        let down = 8 - 5 * (1 - pow(1 - t, 2)) + 0.25 * sin(Double(d) * 0.9)
        let up = 2 + 5 * (1 - pow(1 - t, 2)) + 0.2 * sin(Double(d) * 0.7 + 1)
        return [Point(day: d, value: down, series: ProjectionView.scrolling), Point(day: d, value: up, series: ProjectionView.living)]
    }

    var body: some View {
        OnboardingPage(title: "Less scrolling, more living") {
            VStack(alignment: .leading, spacing: 12) {
                Chart(Self.points) { p in
                    LineMark(x: .value("Day", p.day), y: .value("Hours", p.value))
                        .foregroundStyle(by: .value("Series", p.series))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                .chartForegroundStyleScale([Self.scrolling: Color.brand, Self.living: Color(hex: 0x34C759)])
                .chartXScale(domain: 0...30)
                .chartYScale(domain: 0...9)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: [0, 15, 30]) { value in
                        AxisValueLabel {
                            if let d = value.as(Int.self) { Text("Day \(d)") }
                        }
                    }
                }
                .chartLegend(position: .top, alignment: .leading)
                // The lines draw in left to right with ONE mask animation on the plot area; the chart
                // itself is built once (re-filtering the data every 40ms rebuilt the whole chart).
                .chartPlotStyle { plot in
                    plot.mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: drawn, y: 1, anchor: .leading)
                    }
                }
                .frame(height: 260)
                .padding(16)
                .background(Color.cardWhite, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
                .staggeredAppear(1)
                .accessibilityLabel(Text("Illustration: scrolling goes down and time for living goes up over 30 days."))
                Text("Illustration based on your goals.")
                    .appFont(13)
                    .foregroundStyle(Color.textSecondary)
                    .staggeredAppear(2)
            }
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
        .task {
            if reduceMotion { drawn = 1; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 1.0)) { drawn = 1 }
        }
    }
}
