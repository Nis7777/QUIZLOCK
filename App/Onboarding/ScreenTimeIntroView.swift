import SwiftUI

/// S08: "Take control of your screen time" (step 1 of 2).
struct ScreenTimeIntroView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        ZStack {
            PinkArc()
            VStack(spacing: 0) {
                OnboardingHeader(onBack: onBack, steps: 2, current: 0)
                Spacer(minLength: 10)
                illustration
                Spacer(minLength: 10)
                ScreenTitle(title: "Take control of\nyour screen time", size: 36)
                Text("Choose apps to limit distracting scrolling. Solve a puzzle to unlock them temporarily.")
                    .font(.system(size: 19))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                Text("\(Brand.appName) does not collect your Screen Time usage.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                Spacer()
                PrimaryButton(title: "Continue", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .screenBackground()
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
    }

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.brandRed)
                .frame(width: 150, height: 150)
                .overlay(Image(systemName: "hourglass").font(.system(size: 64, weight: .semibold)).foregroundStyle(.white))
                .rotationEffect(.degrees(appeared ? 10 : 0))
                .offset(x: appeared ? 62 : 0)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white)
                .frame(width: 150, height: 150)
                .overlay(
                    ZStack {
                        Circle().fill(Color.wordmarkRed).frame(width: 112, height: 112)
                        Image(systemName: "key.fill").font(.system(size: 50, weight: .bold)).foregroundStyle(.white)
                            .rotationEffect(.degrees(-45))
                    }
                )
                .rotationEffect(.degrees(appeared ? -8 : 0))
                .offset(x: appeared ? -62 : 0)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        }
        .frame(height: 210)
        .accessibilityHidden(true)
    }
}

/// Soft pink arc filling the bottom ~60% of the background.
struct PinkArc: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Ellipse()
                .fill(Color.brandRed.opacity(0.07))
                .frame(width: w * 2.4, height: geo.size.height * 1.3)
                .position(x: w / 2, y: geo.size.height * 0.4 + geo.size.height * 0.65)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
