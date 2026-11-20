import StoreKit
import SwiftUI

/// Lifetime paywall: Screen A ("Lifetime Access") → Screen B ("Launch offer").
/// Both screens show the price, "One-time purchase", Restore Purchases, Terms of Use and Privacy Policy.
/// Prices always come from StoreKit; if they can't load, we say so and offer a retry (never placeholder prices).
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOffer = false
    @State private var link: URL?

    var body: some View {
        ZStack {
            if showOffer {
                OfferScreen(link: $link,
                            onBuy: { buy(model.store.promo) },
                            onRestore: { restore() },
                            onClose: { close() })
                    .transition(reduceMotion ? .opacity : .push(forward: true))
            } else {
                LifetimeScreen(link: $link,
                               onContinue: { withAnimation(.easeInOut(duration: 0.35)) { showOffer = true } },
                               onBuyStandard: { buy(model.store.standard) },
                               onRestore: { restore() },
                               onClose: { close() })
                    .transition(reduceMotion ? .opacity : .push(forward: false))
            }
        }
        .safariSheet($link)
        .alert("Purchase", isPresented: errorBinding) {
            Button("OK", role: .cancel) { model.store.lastError = nil }
        } message: {
            Text(model.store.lastError ?? "")
        }
        .task { await model.store.loadProductsIfNeeded() }
        .onChange(of: model.settings.hasLifetime) { _, owned in
            if owned { close() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.store.lastError != nil }, set: { if !$0 { model.store.lastError = nil } })
    }

    private func close() {
        model.closePaywall()
        dismiss()
    }

    private func buy(_ product: Product?) {
        Task {
            if await model.store.purchase(product) { close() }
        }
    }

    private func restore() {
        Task {
            await model.store.restore()
            if model.settings.hasLifetime { close() }
        }
    }
}

// MARK: - Shared pieces

/// "Couldn't load prices. Try again" with a retry button.
private struct PricesUnavailable: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    var dark = false

    var body: some View {
        VStack(spacing: 12) {
            if model.store.loadState == .loading {
                ProgressView().controlSize(.large)
                    .accessibilityLabel("Loading prices")
            } else {
                Text("Couldn't load prices. Try again.")
                    .appFont(17, .semibold)
                    .foregroundStyle(dark ? Color.textPrimary : palette.textPrimary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await model.store.loadProducts() }
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .appFont(16, .semibold)
                        .foregroundStyle(Color.brandDeep)
                        .tapTarget()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90)
    }
}

/// Restore Purchases + Terms of Use + Privacy Policy.
private struct PaywallFooter: View {
    @Binding var link: URL?
    let onRestore: () -> Void
    var color: Color = .brandDeep

    var body: some View {
        VStack(spacing: 6) {
            Button("Restore Purchases", action: onRestore)
                .tapTarget()
            HStack(spacing: 24) {
                Button("Terms of Use") { link = Brand.termsURL }.tapTarget()
                Button("Privacy Policy") { link = Brand.privacyURL }.tapTarget()
            }
        }
        .appFont(15, .medium)
        .foregroundStyle(color)
    }
}

// MARK: - Screen A

private struct LifetimeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Binding var link: URL?
    let onContinue: () -> Void
    let onBuyStandard: () -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CloseButton(action: onClose)
            }
            .padding(.horizontal, 12)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    IconTile(systemName: "lock.open.fill", size: 64)
                    Text("Lifetime Access")
                        .appFont(36, .bold)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(model.settings.freeUnlocksRemaining) of your \(Brand.freeUnlocks) free unlocks are left. Get lifetime access with a one-time purchase.")
                        .appFont(18)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    priceCard.padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            VStack(spacing: 10) {
                PrimaryButton(title: "Continue", isLoading: model.store.isPurchasing, action: onContinue)
                if let price = model.store.standardPrice {
                    Button("Pay standard price · \(price)", action: onBuyStandard)
                        .appFont(16, .semibold)
                        .foregroundStyle(palette.accentText)
                        .disabled(model.store.isPurchasing)
                        .tapTarget()
                }
                PaywallFooter(link: $link, onRestore: onRestore, color: palette.accentText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .screenBackground()
    }

    private var priceCard: some View {
        VStack(spacing: 10) {
            if let price = model.store.standardPrice {
                Text(price)
                    .appFont(64, .bold)
                    .foregroundStyle(palette.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("Standard lifetime price").appFont(16).foregroundStyle(palette.textSecondary)
            } else {
                PricesUnavailable()
            }
            Text("One-time purchase. No subscription.").appFont(16).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Divider().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 14) {
                feature("Unlimited puzzle-earned unlocks")
                feature("All 4 puzzle games")
                feature("Pay once, keep lifetime access")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card(padding: 28, radius: 28)
    }

    private func feature(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .appFont(18)
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(text).appFont(17, .medium).foregroundStyle(palette.textPrimary)
        }
    }
}

// MARK: - Screen B

private struct OfferScreen: View {
    @Environment(AppModel.self) private var model
    @Binding var link: URL?
    let onBuy: () -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.paywallCream.ignoresSafeArea()
            Starburst().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .appFont(20, .semibold)
                            .foregroundStyle(Color.brandDeep)
                            .frame(width: 52, height: 52)
                            .background(Color.brand.opacity(0.16), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Image(systemName: "sparkles")
                            .appFont(44, .semibold)
                            .foregroundStyle(Color(hex: 0xF0A01A))
                            .accessibilityHidden(true)
                        Text("Launch offer")
                            .appFont(20, .semibold)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.top, 16)
                        if let percent = model.store.discountPercent, let promo = model.store.promoPrice,
                           let standard = model.store.standardPrice {
                            Text(verbatim: "\(percent)%")
                                .appFont(120, .black, design: .rounded)
                                .foregroundStyle(Color.brand)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .padding(.top, 4)
                                .accessibilityLabel("\(percent) percent off")
                            Text("OFF")
                                .appFont(48, .black, design: .rounded)
                                .tracking(10)
                                .foregroundStyle(Color.brand)
                                .offset(y: -10)
                                .accessibilityHidden(true)
                            Text("Lifetime access for \(promo)")
                                .appFont(21, .semibold)
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("Instead of the standard \(standard). One-time purchase.")
                                .appFont(15)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        } else {
                            PricesUnavailable(dark: true).padding(.top, 20)
                        }
                        ticket.padding(.top, 20)
                        Text("Thank you for supporting \(Brand.appName)")
                            .appFont(17, .semibold)
                            .foregroundStyle(Color.brandDeep)
                            .multilineTextAlignment(.center)
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                Button(action: onBuy) {
                    HStack(spacing: 10) {
                        if model.store.isPurchasing { ProgressView().tint(.white) }
                        Text("Apply discount").appFont(19, .bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 64)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.brandDeep.opacity(0.35), radius: 0, y: 5)
                }
                .buttonStyle(PressableStyle())
                .disabled(model.store.isPurchasing || model.store.promo == nil)
                .opacity(model.store.promo == nil ? 0.5 : 1)
                .padding(.horizontal, 24)
                PaywallFooter(link: $link, onRestore: onRestore)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
        }
        .environment(\.colorScheme, .light)
    }

    private var ticket: some View {
        VStack(spacing: 8) {
            Text("YOUR LIFETIME OFFER")
                .appFont(14, .semibold)
                .tracking(3)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 10) {
                Text(verbatim: "🎟").appFont(18).accessibilityHidden(true)
                Text("One-time lifetime access").appFont(17, .semibold).foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.brand.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }
}

/// Subtle radial light rays. Rotates slowly unless Reduce Motion is on.
private struct Starburst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            let radius = max(geo.size.width, geo.size.height) * 1.2
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let rays = 18
                for i in 0..<rays {
                    let a = Double(i) / Double(rays) * 2 * .pi
                    let half = Double.pi / Double(rays) * 0.45
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + radius * cos(a - half), y: center.y + radius * sin(a - half)))
                    path.addLine(to: CGPoint(x: center.x + radius * cos(a + half), y: center.y + radius * sin(a + half)))
                    path.closeSubpath()
                    context.fill(path, with: .color(Color.white.opacity(0.45)))
                }
            }
            .frame(width: radius * 2, height: radius * 2)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            .rotationEffect(.degrees(rotation), anchor: UnitPoint(x: 0.5, y: 0.42))
            .mask(RadialGradient(colors: [.white, .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.42),
                                 startRadius: 0, endRadius: radius * 0.6))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}
