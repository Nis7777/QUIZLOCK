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
struct RealityCheckView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let years = model.profile.yearsOnPhone
        OnboardingPage {
            VStack(spacing: 14) {
                MascotSlot(expression: .sad, size: 190)
                    .padding(.top, 10)
                Text("At this rate, you'll spend")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(1)
                CountUpNumber(target: years, fractionDigits: 1, delay: 0.5)
                    .appFont(76, .black, design: .rounded)
                    .foregroundStyle(Color(hex: 0xFF3B30))
                    .staggeredAppear(2)
                Text("years of your life scrolling.")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(3)
                Text("Based on your daily scrolling time, until age 80.")
                    .appFont(14)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 6)
                    .staggeredAppear(4)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
    }
}

/// 5.3 "With QuizLock, you could get back Y years." (Y = 50% of X), with light confetti.
struct GetBackView: View {
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @State private var celebrate = false

    var body: some View {
        OnboardingPage {
            VStack(spacing: 14) {
                MascotSlot(expression: .celebrate, size: 200)
                    .padding(.top, 10)
                Text("With \(Brand.appName), you could get back")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(1)
                CountUpNumber(target: model.profile.yearsBack, fractionDigits: 1, delay: 0.5)
                    .appFont(76, .black, design: .rounded)
                    .foregroundStyle(Color.brand)
                    .staggeredAppear(2)
                Text("years.")
                    .appFont(24, .bold, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
                    .staggeredAppear(3)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        } footer: {
            ChunkyButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("onboarding.continue")
        }
        .confetti(celebrate, origin: UnitPoint(x: 0.5, y: 0.3))
        .task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            celebrate = true
        }
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
                Chart(Self.points.filter { Double($0.day) <= drawn * 30 }) { p in
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
            // The lines draw themselves in (a trim-like reveal over ~1.2s).
            if reduceMotion { drawn = 1; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            for i in 1...30 {
                withAnimation(.linear(duration: 0.04)) { drawn = Double(i) / 30 }
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }
}
