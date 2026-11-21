import SwiftUI
import UIKit

// MARK: - Chapter 7: Commitment

/// 7.1 Hold-to-commit: a coral circle grows from the fingerprint button over 1.6s while held, with
/// ramping haptics. Releasing early springs it back; completing turns the whole screen coral.
struct CommitView: View {
    let onCommitted: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var holding = false
    @State private var done = false
    @State private var holdTask: Task<Void, Never>?

    private static let holdDuration = 1.6

    var body: some View {
        GeometryReader { geo in
            let buttonCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height - 76)
            let diameter = hypot(geo.size.width, geo.size.height) * 2.2
            ZStack {
                VStack(spacing: 18) {
                    MascotSlot(expression: .thinking, size: 210)
                        .scaleEffect(1 + progress * 0.12)
                        .padding(.top, 30)
                    Text("Are you ready to take your time back, \(model.friendlyName)?")
                        .appFont(32, .heavy, design: .rounded)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .accessibilityAddTraits(.isHeader)
                        .staggeredAppear(1)
                    Spacer()
                    Text("Hold your finger on the button to commit")
                        .appFont(16, .semibold)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.bottom, 140)
                        .staggeredAppear(2)
                }
                .frame(maxWidth: .infinity)

                Circle()
                    .fill(Color.brand)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(done ? 1 : progress * 0.9)
                    .position(buttonCenter)
                    .allowsHitTesting(false)

                fingerprint
                    .position(buttonCenter)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onDisappear { holdTask?.cancel() }
    }

    private var fingerprint: some View {
        Image(systemName: "touchid")
            .font(.system(size: 46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 96, height: 96)
            .background(Circle().fill(Color.brand))
            .background(Circle().fill(Color.brandDeep).offset(y: holding ? 1 : 5))
            .overlay(Circle().strokeBorder(.white.opacity(holding ? 0.8 : 0), lineWidth: 3))
            .scaleEffect(holding ? 0.94 : 1)
            .animation(Motion.snappy, value: holding)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !holding && !done { begin() } }
                    .onEnded { _ in if !done { cancel() } }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Commit"))
            .accessibilityHint(Text("Double-tap to commit"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { complete() }
            .accessibilityIdentifier("onboarding.commit")
    }

    private func begin() {
        holding = true
        withAnimation(.linear(duration: Self.holdDuration * (1 - progress))) { progress = 1 }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            let start = Date()
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            while !Task.isCancelled {
                let t = Date().timeIntervalSince(start) / Self.holdDuration
                if t >= 1 { break }
                // Continuous haptics ramping up in strength and rate.
                generator.impactOccurred(intensity: 0.3 + 0.7 * t)
                try? await Task.sleep(nanoseconds: UInt64((0.14 - 0.09 * t) * 1_000_000_000))
            }
            if !Task.isCancelled { complete() }
        }
    }

    private func cancel() {
        holding = false
        holdTask?.cancel()
        withAnimation(Motion.respecting(reduceMotion, Motion.bouncy)) { progress = 0 }
    }

    private func complete() {
        guard !done else { return }
        holdTask?.cancel()
        holding = false
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) {
            done = true
            progress = 1
        }
        model.updateProfile { $0.committed = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            onCommitted()
        }
    }
}

/// 7.2 Full coral screen: "You're about to…" → "Unlock" types itself → "(verb)" → the paragraph line by line.
struct AboutToView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showIntro = false
    @State private var typed = 0
    @State private var showVerb = false
    @State private var lines = 0
    @State private var showButton = false

    private let word = String(localized: "Unlock")
    private let paragraph = [
        String(localized: "To earn your scroll."),
        String(localized: "You solve a puzzle, your brain wakes up,"),
        String(localized: "and the app gets a little less powerful every time."),
    ]

    var body: some View {
        ZStack {
            Color.brand.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                Text("You're about to…")
                    .appFont(24, .bold, design: .rounded)
                    .opacity(showIntro ? 1 : 0)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: String(word.prefix(typed)))
                        .appFont(64, .black, design: .rounded)
                    Text("(verb)")
                        .appFont(22, .semibold)
                        .italic()
                        .opacity(showVerb ? 0.85 : 0)
                }
                .frame(minHeight: 80, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(paragraph.indices, id: \.self) { i in
                        Text(verbatim: paragraph[i])
                            .appFont(19, .medium)
                            .opacity(i < lines ? 1 : 0)
                            .offset(y: i < lines || reduceMotion ? 0 : 8)
                    }
                }
                .padding(.top, 12)
                Spacer()
                ChunkyButton(title: "Let's go", style: .white, action: onContinue)
                    .accessibilityIdentifier("onboarding.letsGo")
                    .opacity(showButton ? 1 : 0)
                    .disabled(!showButton)
                    .padding(.bottom, 10)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
        }
        .accessibilityElement(children: .contain)
        .task { await play() }
    }

    private func play() async {
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                showIntro = true; typed = word.count; showVerb = true; lines = paragraph.count; showButton = true
            }
            return
        }
        await wait(0.3)
        withAnimation(Motion.gentle) { showIntro = true }
        await wait(0.8)
        let tick = UISelectionFeedbackGenerator()
        for i in 1...word.count {
            typed = i
            tick.selectionChanged()
            await wait(0.11)
        }
        await wait(0.25)
        withAnimation(Motion.gentle) { showVerb = true }
        await wait(0.6)
        for i in 1...paragraph.count {
            withAnimation(Motion.gentle) { lines = i }
            await wait(0.55)
        }
        withAnimation(Motion.bouncy) { showButton = true }
    }
}

/// 7.3 "Setting up QuizLock…": a coral semicircle arc around a calm Lockie; 3 steps tick off (~3s).
struct SettingUpView: View {
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var doneSteps = 0

    private let steps = ["Analyzing your answers", "Building your plan", "Locking in your puzzles"]

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.brandTint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(180))
                Circle()
                    .trim(from: 0, to: 0.5 * progress)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(180))
                MascotSlot(expression: .calm, size: 180)
                    .offset(y: -20)
            }
            .frame(width: 270, height: 270)
            .padding(.bottom, -100)
            Text(verbatim: String(localized: "Setting up \(Brand.appName)…"))
                .appFont(28, .heavy, design: .rounded)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(steps.indices, id: \.self) { i in
                    let done = i < doneSteps
                    HStack(spacing: 14) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(done ? Color.brand : Color.textSecondary.opacity(0.35))
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: done)
                        Text(LocalizedStringKey(steps[i]))
                            .appFont(18, done ? .semibold : .regular)
                            .foregroundStyle(done ? Color.textPrimary : Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 6)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: doneSteps)
        .task {
            let per = reduceMotion ? 0.4 : 1.0
            for i in 1...steps.count {
                withAnimation(.easeInOut(duration: per)) { progress = Double(i) / Double(steps.count) }
                try? await Task.sleep(nanoseconds: UInt64(per * 1_000_000_000))
                withAnimation(Motion.bouncy) { doneSteps = i }
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            onDone()
        }
    }
}

/// 7.4 Plan ready: coral sky, celebrating Lockie, confetti, and the plan card → paywall.
struct PlanReadyView: View {
    let onStart: () -> Void
    @Environment(AppModel.self) private var model
    @State private var celebrate = false

    var body: some View {
        ZStack {
            CoralSky()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    MascotSlot(expression: .celebrate, size: 180)
                        .padding(.top, 20)
                    Text("In 4 weeks, you won't recognize your screen time, \(model.friendlyName).")
                        .appFont(30, .heavy, design: .rounded)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.brandDeep.opacity(0.3), radius: 8, y: 3)
                        .padding(.horizontal, 10)
                        .accessibilityAddTraits(.isHeader)
                        .staggeredAppear(1)
                    planCard.staggeredAppear(2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom) {
                ChunkyButton(title: "Start my plan", style: .white, shimmer: true, action: onStart)
                    .accessibilityIdentifier("onboarding.startPlan")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .staggeredAppear(4)
            }
        }
        .confetti(celebrate, origin: UnitPoint(x: 0.5, y: 0.2))
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            celebrate = true
        }
    }

    private var planCard: some View {
        let categories = model.profile.suggestedCategories
            .map { String(localized: String.LocalizationValue($0.label)) }
            .formatted(.list(type: .and))
        let challenge = model.profile.challenge ?? .balanced
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(hex: 0x34C759))
                Text("Your personalized plan is ready")
                    .appFont(19, .heavy, design: .rounded)
                    .foregroundStyle(Color.textPrimary)
            }
            Divider()
            planRow(symbol: "lock.fill", title: "Locked", value: categories)
            planRow(symbol: "puzzlepiece.extension.fill", title: "Daily puzzle mix",
                    value: "\(model.enabledGamesText) · \(String(localized: String.LocalizationValue(challenge.label)))")
            planRow(symbol: "timer", title: "Unlock time",
                    value: String(localized: String.LocalizationValue(model.lock.defaultDuration.label)))
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.brandDeep.opacity(0.2), radius: 18, y: 8)
    }

    private func planRow(symbol: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .appFont(16, .bold)
                .foregroundStyle(Color.brand)
                .frame(width: 34, height: 34)
                .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .appFont(13, .bold)
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                Text(verbatim: value)
                    .appFont(16, .semibold)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
