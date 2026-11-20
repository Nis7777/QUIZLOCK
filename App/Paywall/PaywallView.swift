import StoreKit
import SwiftUI

/// Lifetime paywall: Screen A ("Lifetime Access") → Screen B ("Your lifetime discount").
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscount = false
    @State private var link: URL?

    var body: some View {
        ZStack {
            if showDiscount {
                DiscountScreen(onClose: { close() }, onApply: { buy(model.store.promo) })
                    .transition(.push(forward: true))
            } else {
                LifetimeScreen(link: $link,
                               onContinue: { withAnimation(.easeInOut(duration: 0.35)) { showDiscount = true } },
                               onBuyStandard: { buy(model.store.standard) },
                               onRestore: { restore() },
                               onClose: { close() })
                    .transition(.push(forward: false))
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
                CloseButton(action: onClose).foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 12)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    IconTile(systemName: "lock.open.fill", size: 64)
                    Text("Lifetime Access")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("\(model.settings.freeUnlocksRemaining) of your \(Brand.freeUnlocks) free unlocks are left. Get lifetime access with a one-time purchase.")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    priceCard.padding(.top, 8)
                    HStack(spacing: 28) {
                        Button("Terms of Service") { link = Brand.termsURL }
                        Button("Privacy Policy") { link = Brand.privacyURL }
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(palette.accentText)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
            }
            VStack(spacing: 18) {
                PrimaryButton(title: "Continue", isLoading: model.store.isPurchasing, action: onContinue)
                if let price = model.store.standardPrice {
                    Button("Pay standard price · \(price)", action: onBuyStandard)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.accentText)
                        .disabled(model.store.isPurchasing || model.store.promo == nil)
                .opacity(model.store.promo == nil ? 0.5 : 1)
                }
                Button("Restore Purchases", action: onRestore)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.accentText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .screenBackground()
    }

    private var priceCard: some View {
        VStack(spacing: 10) {
            Text(model.store.standardPrice ?? " ")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .overlay {
                    if model.store.standardPrice == nil { ProgressView().controlSize(.large) }
                }
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Standard lifetime price").font(.system(size: 16)).foregroundStyle(palette.textSecondary)
            Text("One-time purchase. No subscription.").font(.system(size: 16)).foregroundStyle(palette.textSecondary)
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

    private func feature(_ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(palette.accent)
            Text(text).font(.system(size: 17, weight: .medium)).foregroundStyle(palette.textPrimary)
        }
    }
}

private struct DiscountScreen: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void
    let onApply: () -> Void

    var body: some View {
        ZStack {
            Color.paywallCream.ignoresSafeArea()
            Starburst().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.brandDeep)
                            .frame(width: 52, height: 52)
                            .background(Color.brand.opacity(0.16), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF0A01A))
                Text("Your lifetime discount")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 20)
                Text(verbatim: model.store.discountPercent.map { "\($0)%" } ?? " ")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(Color.brand)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.top, 8)
                Text("OFF")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(10)
                    .foregroundStyle(Color.brand)
                    .offset(y: -12)
                Text(model.store.promoPrice.map { "Lifetime access for \($0)" } ?? "Loading price…")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 8)
                ticket.padding(.top, 20)
                Text("Thank you for supporting \(Brand.appName)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandDeep)
                    .padding(.top, 20)
                Spacer()
                Button(action: onApply) {
                    HStack(spacing: 10) {
                        if model.store.isPurchasing { ProgressView().tint(.white) }
                        Text("Apply discount").font(.system(size: 19, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.3), radius: 0, y: 5)
                }
                .buttonStyle(PressableStyle())
                .disabled(model.store.isPurchasing || model.store.promo == nil)
                .opacity(model.store.promo == nil ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .environment(\.colorScheme, .light)
    }

    private var ticket: some View {
        VStack(spacing: 8) {
            Text("YOUR LIFETIME OFFER")
                .font(.system(size: 14, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 10) {
                Text("🎟").font(.system(size: 18))
                Text("One-time lifetime access").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.brand.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }
}

/// Subtle radial light rays, slowly rotating.
private struct Starburst: View {
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
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}
