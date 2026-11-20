import SwiftUI

/// S04: animated phone mockup in 3 beats: home screen → shield → the picked game.
struct HowItWorksView: View {
    let game: GameID
    let onBack: () -> Void
    let onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var beat = 1
    @State private var tapPoint: CGPoint?
    @State private var tapPulse = false
    @State private var zoom = false
    @State private var previewRound: AnyRound?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            ScreenTitle(title: "Here's how\n\(Brand.appName) works", size: 34)
                .padding(.top, 2)
            GeometryReader { geo in
                let width = min(geo.size.width * 0.66, (geo.size.height - 50) / 1.98)
                VStack(spacing: 18) {
                    PhoneMockup(width: width, screenColor: beat == 1 ? .clear : .white) {
                        screen(width: width)
                    }
                    .overlay { tapIndicator }
                    .scaleEffect(zoom ? 1.6 : 1)
                    .opacity(zoom ? 0 : 1)
                    Text("Solve the puzzle to unlock the app")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .opacity(beat == 3 ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 18)
        }
        .screenBackground()
        .task { await play() }
    }

    @ViewBuilder
    private func screen(width: CGFloat) -> some View {
        switch beat {
        case 1: homeScreen(width: width).transition(.opacity)
        case 2: shieldScreen(width: width).transition(.opacity)
        default: gameScreen(width: width).transition(.opacity)
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
                            Text("Instagram").font(.system(size: width * 0.034))
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

    // MARK: Beat 3 – the picked game, scaled down

    private func gameScreen(width: CGFloat) -> some View {
        let fullWidth: CGFloat = 393
        let scale = (width * 0.93) / fullWidth
        return PuzzleChrome(game: game, subLabel: previewRound?.subLabel ?? "", isPractice: true) {
            if let round = previewRound {
                PuzzleGameView(round: round, dictionary: model.rounds.wordDictionary, onFinish: { _ in })
            }
        }
        .frame(width: fullWidth, height: fullWidth * 1.85)
        .scaleEffect(scale)
        .frame(width: width * 0.93, height: fullWidth * 1.85 * scale)
        .allowsHitTesting(false)
        .environment(\.palette, .classic)
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
        previewRound = model.rounds.onboardingRound(game)
        try? await Task.sleep(nanoseconds: 900_000_000)
        await tap(at: CGPoint(x: 0.26, y: 0.27))
        withAnimation(.easeInOut(duration: 0.4)) { beat = 2 }
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        await tap(at: CGPoint(x: 0.5, y: 0.82))
        withAnimation(.easeInOut(duration: 0.4)) { beat = 3 }
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.45)) { zoom = true }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        onFinish()
    }
}
