import SwiftUI

/// "Here's how QuizLock works": a fully automatic phone demo — home screen → shield → a puzzle that solves
/// itself → "You unlocked the app!" → "Enjoy your feed." Nothing to play. "Skip" (top right) jumps ahead;
/// a single Continue appears at the end.
struct HowItWorksView: View {
    let onBack: () -> Void
    let onFinish: () -> Void
    @Environment(\.palette) private var palette
    @State private var beat = 1
    @State private var tapPoint: CGPoint?
    @State private var tapPulse = false
    @State private var typed = false
    @State private var solved = false
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(action: onBack)
                Spacer()
                if !finished {
                    Button("Skip", action: onFinish)
                        .appFont(17, .semibold)
                        .foregroundStyle(palette.accentText)
                        .tapTarget()
                        .accessibilityIdentifier("onboarding.skip")
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            ScreenTitle(title: title, subtitle: beat == 5 ? String(localized: "You've earned it!") : nil, size: 34)
                .padding(.top, 2)
                .id(title)
                .transition(.opacity)
            GeometryReader { geo in
                let width = min(geo.size.width * 0.66, (geo.size.height - 50) / 1.98)
                VStack(spacing: 18) {
                    PhoneMockup(width: width, screenColor: beat == 1 ? .clear : .white) {
                        screen(width: width)
                    }
                    .overlay { tapIndicator }
                    Text(caption)
                        .appFont(20, .medium)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(caption.isEmpty ? 0 : 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 18)
            PrimaryButton(title: "Continue", action: onFinish)
                .accessibilityIdentifier("onboarding.continue")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .opacity(finished ? 1 : 0)
                .disabled(!finished)
                .accessibilityHidden(!finished)
        }
        .screenBackground()
        .confetti(beat == 4)
        .task { await play() }
    }

    private var title: String {
        switch beat {
        case 4: return String(localized: "You unlocked the app!")
        case 5: return String(localized: "Enjoy your feed.")
        default: return String(localized: "Here's how\n\(Brand.appName) works")
        }
    }

    private var caption: String {
        switch beat {
        case 2: return String(localized: "Your locked app shows a shield")
        case 3: return String(localized: "Solve the puzzle to unlock the app")
        default: return ""
        }
    }

    @ViewBuilder
    private func screen(width: CGFloat) -> some View {
        switch beat {
        case 1: homeScreen(width: width).transition(.opacity)
        case 2: shieldScreen(width: width).transition(.opacity)
        case 3: puzzleScreen(width: width).transition(.opacity)
        case 4: unlockedScreen(width: width).transition(.opacity)
        default: feedScreen(width: width).transition(.opacity)
        }
    }

    // MARK: Beat 1 – home screen

    private func homeScreen(width: CGFloat) -> some View {
        let icon = width * 0.19
        return ZStack {
            LinearGradient(colors: [Color(hex: 0xC9CDF2), Color(hex: 0xE5D9EC), Color(hex: 0xF6D5C8)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -width * 0.16)
                .padding(.bottom, -width * 0.06)
            VStack(spacing: width * 0.06) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: width * 0.052, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.75))
                HStack(spacing: width * 0.12) {
                    VStack(spacing: 4) {
                        MockAppIcon.social(size: icon)
                            .scaleEffect(tapPulse && beat == 1 ? 0.88 : 1)
                        HStack(spacing: 2) {
                            Image(systemName: "hourglass").font(.system(size: width * 0.03))
                            Text("Social").font(.system(size: width * 0.034))
                        }
                        .foregroundStyle(Color.black.opacity(0.8))
                    }
                    VStack(spacing: 4) {
                        MockAppIcon(symbol: "photo.on.rectangle", colors: [Color(hex: 0xFF9F0A), Color(hex: 0xFF7A00)], size: icon)
                        Text(" ").font(.system(size: width * 0.034))
                    }
                    VStack(spacing: 4) {
                        MockAppIcon(symbol: "camera.fill", colors: [Color(hex: 0x8E8E93), Color(hex: 0x636366)], size: icon)
                        Text(" ").font(.system(size: width * 0.034))
                    }
                }
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: width * 0.12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: icon * 0.24, style: .continuous)
                                .fill(Color.white.opacity(0.4))
                                .frame(width: icon, height: icon)
                        }
                    }
                }
                Spacer()
                HStack(spacing: width * 0.1) {
                    MockAppIcon(symbol: "phone.fill", colors: [Color(hex: 0x34C759), Color(hex: 0x28A745)], size: icon)
                    MockAppIcon(symbol: "message.fill", colors: [Color(hex: 0x34C759), Color(hex: 0x28A745)], size: icon)
                    MockAppIcon(symbol: "safari.fill", colors: [Color(hex: 0x0A84FF), Color(hex: 0x0060DF)], size: icon)
                }
                .padding(width * 0.035)
                .background(Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: width * 0.09, style: .continuous))
                .padding(.bottom, width * 0.03)
            }
            .padding(.top, width * 0.05)
        }
    }

    // MARK: Beat 2 – shield

    private func shieldScreen(width: CGFloat) -> some View {
        VStack(spacing: width * 0.05) {
            Spacer()
            ZStack {
                Circle().fill(Color.brand).frame(width: width * 0.27, height: width * 0.27)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: width * 0.11, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Solve a puzzle to unlock the app")
                .font(.system(size: width * 0.07, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, width * 0.08)
            Spacer()
            Text("START PUZZLE")
                .font(.system(size: width * 0.05, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: width * 0.15)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: width * 0.04, style: .continuous))
                .scaleEffect(tapPulse && beat == 2 ? 0.94 : 1)
                .padding(.horizontal, width * 0.08)
            Text("NOT NOW")
                .font(.system(size: width * 0.042, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .padding(.bottom, width * 0.08)
        }
    }

    // MARK: Beat 3 – a puzzle that solves itself

    private func puzzleScreen(width: CGFloat) -> some View {
        VStack(spacing: width * 0.08) {
            HStack(spacing: 6) {
                Image(systemName: "function")
                Text("Math")
                Spacer()
                ZStack {
                    Circle().fill(Color.correctGreen)
                    Image(systemName: "checkmark").font(.system(size: width * 0.03, weight: .heavy)).foregroundStyle(.white)
                }
                .frame(width: width * 0.07, height: width * 0.07)
                .scaleEffect(solved ? 1 : 0.01)
                .opacity(solved ? 1 : 0)
            }
            .font(.system(size: width * 0.05, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, width * 0.07)
            Spacer()
            Text("If 3x + 5 = 20,\nwhat is x?")
                .font(.system(size: width * 0.085, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Text(verbatim: solved ? "x = 5" : (typed ? "5" : " "))
                    .font(.system(size: width * 0.075, weight: .semibold, design: .rounded))
                    .foregroundStyle(solved ? Color.answerGreen : Color.textPrimary)
                if solved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: width * 0.065))
                        .foregroundStyle(Color.answerGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: width * 0.18)
            .background(solved ? Color.correctGreenBg : Color(hex: 0xF4F4F7),
                        in: RoundedRectangle(cornerRadius: width * 0.045, style: .continuous))
            .padding(.horizontal, width * 0.08)
            Spacer()
            Spacer()
        }
        .padding(.top, width * 0.02)
        .accessibilityElement(children: .combine)
    }

    // MARK: Beat 4 – unlocked

    private func unlockedScreen(width: CGFloat) -> some View {
        VStack(spacing: width * 0.07) {
            HStack(spacing: 3) {
                Image(systemName: "arrowtriangle.left.fill").font(.system(size: width * 0.03))
                Text("Social").font(.system(size: width * 0.045, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Color(hex: 0x0A84FF))
            .padding(.horizontal, width * 0.06)
            .padding(.top, -width * 0.06)
            Spacer()
            ZStack {
                Circle().fill(Color.brandTint).frame(width: width * 0.36, height: width * 0.36)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: width * 0.15, weight: .semibold))
                    .foregroundStyle(Color.brand)
            }
            Text("Tap the app at the top left\nto return to your app.")
                .font(.system(size: width * 0.055, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
    }

    // MARK: Beat 5 – the feed

    private func feedScreen(width: CGFloat) -> some View {
        let grey = Color(hex: 0xD8D8DD)
        return VStack(alignment: .leading, spacing: width * 0.035) {
            HStack {
                Text(verbatim: "Social").font(.system(size: width * 0.07, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "heart")
                Image(systemName: "paperplane")
            }
            .font(.system(size: width * 0.06))
            .foregroundStyle(Color.textPrimary)
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: width * 0.025) {
                    HStack(spacing: width * 0.03) {
                        Circle().fill(grey).frame(width: width * 0.09, height: width * 0.09)
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(grey).frame(width: width * 0.3, height: width * 0.025)
                            Capsule().fill(grey).frame(width: width * 0.18, height: width * 0.02)
                        }
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xECECEF))
                        Image(systemName: "photo").font(.system(size: width * 0.1)).foregroundStyle(Color(hex: 0xB8B8BE))
                    }
                    .frame(height: width * 0.48)
                    HStack(spacing: width * 0.04) {
                        Image(systemName: "heart")
                        Image(systemName: "bubble.right")
                        Image(systemName: "paperplane")
                        Spacer()
                        Image(systemName: "bookmark")
                    }
                    .font(.system(size: width * 0.05))
                    .foregroundStyle(Color(hex: 0x9A9AA0))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, width * 0.05)
        .accessibilityHidden(true)
    }

    // MARK: Animation

    @ViewBuilder
    private var tapIndicator: some View {
        if let p = tapPoint {
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                    .frame(width: 34, height: 34)
                    .scaleEffect(tapPulse ? 0.75 : 1.15)
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func tap(at point: CGPoint) async {
        withAnimation(.easeOut(duration: 0.25)) { tapPoint = point }
        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.easeInOut(duration: 0.18)) { tapPulse = true }
        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.easeInOut(duration: 0.18)) { tapPulse = false }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeOut(duration: 0.2)) { tapPoint = nil }
    }

    private func play() async {
        func wait(_ seconds: Double) async -> Bool {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        }
        guard await wait(0.8) else { return }
        await tap(at: CGPoint(x: 0.26, y: 0.27))
        withAnimation(.easeInOut(duration: 0.4)) { beat = 2 }
        guard await wait(1.0) else { return }
        await tap(at: CGPoint(x: 0.5, y: 0.82))
        withAnimation(.easeInOut(duration: 0.4)) { beat = 3 }
        guard await wait(0.9) else { return }
        withAnimation(.easeOut(duration: 0.2)) { typed = true }
        guard await wait(0.5) else { return }
        Haptics.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { solved = true }
        guard await wait(1.0) else { return }
        withAnimation(.easeInOut(duration: 0.45)) { beat = 4 }
        guard await wait(1.8) else { return }
        withAnimation(.easeInOut(duration: 0.45)) { beat = 5 }
        guard await wait(0.6) else { return }
        withAnimation(.easeOut(duration: 0.3)) { finished = true }
    }
}
