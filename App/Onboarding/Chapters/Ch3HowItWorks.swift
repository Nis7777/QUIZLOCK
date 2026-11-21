import SwiftUI

// MARK: - Chapter 3: How it works

/// Three swipeable cards (auto-advance every 3.5s) with phone mock-ups drawn in SwiftUI.
struct HowItWorksCardsView: View {
    let onContinue: () -> Void
    @State private var page = 0
    @State private var userSwiped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cards: [(title: String, subtitle: String)] = [
        ("Your apps get locked", "Pick the apps that steal your time."),
        ("Solve to unlock", "A quick puzzle stands between you and the scroll."),
        ("Earn your scroll", "Unlocked for a few minutes. Then it locks again."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { i in
                    VStack(spacing: 22) {
                        PhoneMock {
                            switch i {
                            case 0: LockedAppsScene(active: page == 0)
                            case 1: SolveScene(active: page == 1)
                            default: EarnScene(active: page == 2)
                            }
                        }
                        .frame(height: 340)
                        VStack(spacing: 10) {
                            Text(LocalizedStringKey(cards[i].title))
                                .appFont(30, .heavy, design: .rounded)
                                .foregroundStyle(Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text(LocalizedStringKey(cards[i].subtitle))
                                .appFont(17)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 28)
                        .staggeredAppear(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 8)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .simultaneousGesture(DragGesture().onChanged { _ in userSwiped = true })

            HStack(spacing: 8) {
                ForEach(cards.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.brand : Color.textSecondary.opacity(0.25))
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(Motion.snappy, value: page)
            .padding(.bottom, 18)
            .accessibilityHidden(true)

            ChunkyButton(title: "Continue") {
                if page < cards.count - 1 {
                    withAnimation(Motion.smooth) { page += 1 }
                } else {
                    onContinue()
                }
            }
            .accessibilityIdentifier("onboarding.continue")
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .sensoryFeedback(.selection, trigger: page)
        .task(id: page) {
            // Auto-advance after 3.5s (stops once the user swipes or reaches the last card).
            guard !userSwiped, page < cards.count - 1 else { return }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled, !userSwiped else { return }
            withAnimation(Motion.respecting(reduceMotion, Motion.smooth)) { page += 1 }
        }
    }
}

/// A simple iPhone outline with a screen area.
struct PhoneMock<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(Color(hex: 0x1C1C1E), lineWidth: 8))
            .overlay(alignment: .top) {
                Capsule().fill(Color(hex: 0x1C1C1E)).frame(width: 70, height: 20).padding(.top, 14)
            }
            .overlay { content().padding(.horizontal, 22).padding(.vertical, 44) }
            .frame(width: 190)
            .shadow(color: Color.brand.opacity(0.18), radius: 24, y: 12)
            .accessibilityHidden(true)
    }
}

private let sampleIcons = ["tiktok", "instagram", "youtube", "snapchat", "reddit", "x"]

/// Card 1: icons slide in, then a coral padlock clicks shut over them.
private struct LockedAppsScene: View {
    let active: Bool
    @State private var arrived = false
    @State private var locked = false

    var body: some View {
        ZStack {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 14), count: 3), spacing: 14) {
                ForEach(0..<6, id: \.self) { i in
                    BrandAppIcon(name: sampleIcons[i], size: 40)
                        .offset(y: arrived ? 0 : 260)
                        .opacity(arrived ? (locked ? 0.35 : 1) : 0)
                        .animation(Motion.bouncy.delay(Double(i) * Motion.stagger), value: arrived)
                        .animation(Motion.smooth, value: locked)
                }
            }
            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color.brand)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: locked)
                .scaleEffect(arrived ? 1 : 0.4)
                .opacity(arrived ? 1 : 0)
                .animation(Motion.bouncy.delay(0.4), value: arrived)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: locked) { _, now in now }
        .task(id: active) {
            guard active else { arrived = false; locked = false; return }
            arrived = true
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            locked = true
        }
    }
}

/// Card 2: the shield appears and a mini word puzzle solves itself.
private struct SolveScene: View {
    let active: Bool
    @State private var filled = 0
    @State private var shield = false
    private let word = Array("SMART")

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Color.brand)
                .scaleEffect(shield ? 1 : 0.4)
                .opacity(shield ? 1 : 0)
                .animation(Motion.bouncy, value: shield)
            Text("Solve to unlock")
                .appFont(12, .bold)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 5) {
                ForEach(word.indices, id: \.self) { i in
                    let done = i < filled
                    Text(verbatim: done ? String(word[i]) : "")
                        .appFont(18, .heavy, design: .rounded)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 28)
                        .background(done ? Color(hex: 0x34C759) : Color(hex: 0xE5E5EA),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .scaleEffect(done ? 1 : 0.9)
                        .animation(Motion.bouncy, value: done)
                }
            }
            Image(systemName: filled >= word.count ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(filled >= word.count ? Color(hex: 0x34C759) : Color.textSecondary.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(.selection, trigger: filled)
        .task(id: active) {
            guard active else { filled = 0; shield = false; return }
            shield = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            for i in 1...word.count {
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
                filled = i
            }
        }
    }
}

/// Card 3: the lock opens, a 15:00 ring counts down (sped up), then the lock closes again.
private struct EarnScene: View {
    let active: Bool
    @State private var open = false
    @State private var remaining = 1.0

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: open ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.brand)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: open)
            ZStack {
                Circle().stroke(Color.brandTint, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: remaining)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: timeText)
                    .appFont(20, .heavy, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: 104, height: 104)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: open)
        .task(id: active) {
            guard active else { open = false; remaining = 1; return }
            remaining = 1
            try? await Task.sleep(nanoseconds: 300_000_000)
            open = true
            for step in stride(from: 15, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.12)) { remaining = Double(step) / 15 }
            }
            open = false
        }
    }

    private var timeText: String {
        let minutes = Int((remaining * 15).rounded())
        return String(format: "%02d:00", minutes)
    }
}
