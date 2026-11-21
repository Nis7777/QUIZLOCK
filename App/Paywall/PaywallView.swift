import StoreKit
import SwiftUI

/// QuizLock Pro paywall (auto-renewable subscriptions).
/// Main screen: yearly (pre-selected, free trial when eligible) or monthly → on close, the exit offer (shown once).
/// Every screen shows price + period, "Auto-renews. Cancel anytime in Settings.", Restore Purchases,
/// Terms of Use, Privacy Policy and a visible close button. Prices, periods and the trial come from StoreKit.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOffer = false
    @State private var link: URL?

    var body: some View {
        ZStack {
            if showOffer {
                ExitOfferScreen(link: $link,
                                onBuy: { buy(model.store.yearlyOffer) },
                                onRestore: { restore() },
                                onClose: { close() })
                    .transition(reduceMotion ? .opacity : .push(forward: true))
            } else {
                PlansScreen(link: $link,
                            onBuy: { buy($0) },
                            onRestore: { restore() },
                            onClose: { closeMain() })
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
        .onChange(of: model.settings.isPro) { _, pro in
            if pro { close() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.store.lastError != nil }, set: { if !$0 { model.store.lastError = nil } })
    }

    /// Closing the main paywall shows the exit offer once (if it loaded); after that it just closes.
    private func closeMain() {
        if !model.settings.exitOfferShown, !model.settings.isPro, model.store.yearlyOffer != nil,
           model.store.offerDiscountPercent != nil {
            model.updateSettings { $0.exitOfferShown = true }
            withAnimation(.easeInOut(duration: 0.35)) { showOffer = true }
        } else {
            close()
        }
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
            if model.settings.isPro {
                close()
            } else if model.store.lastError == nil {
                model.store.lastError = String(localized: "No active subscription was found for this Apple ID.")
            }
        }
    }
}

// MARK: - Shared pieces

/// "Couldn't load prices" with a Retry button (never placeholder prices).
private struct PricesUnavailable: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            if model.store.loadState == .loading {
                ProgressView().controlSize(.large)
                    .accessibilityLabel("Loading prices")
            } else {
                Text("Couldn't load prices")
                    .appFont(17, .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await model.store.loadProducts() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .appFont(16, .semibold)
                        .foregroundStyle(palette.accentText)
                        .tapTarget()
                }
                .accessibilityIdentifier("paywall.retry")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90)
    }
}

/// "Auto-renews. Cancel anytime in Settings." + Restore Purchases + Terms of Use + Privacy Policy.
private struct PaywallFooter: View {
    @Binding var link: URL?
    let onRestore: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 4) {
            Text("Auto-renews. Cancel anytime in Settings.")
                .appFont(13)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore Purchases", action: onRestore).tapTarget()
                Button("Terms of Use") { link = Brand.termsURL }.tapTarget()
                Button("Privacy Policy") { link = Brand.privacyURL }.tapTarget()
            }
            .appFont(13, .semibold)
            .foregroundStyle(palette.accentText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

private struct PaywallCloseButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .appFont(17, .bold)
                .foregroundStyle(palette.textSecondary)
                .frame(width: 36, height: 36)
                .background(palette.separator.opacity(0.6), in: Circle())
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("paywall.close")
    }
}

// MARK: - Main screen

private enum Plan { case yearly, monthly }

private struct PlansScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Binding var link: URL?
    let onBuy: (Product?) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void
    @State private var plan: Plan = .yearly
    @State private var count = CountUpState()

    private var store: Store { model.store }
    private var selectedProduct: Product? { plan == .yearly ? store.yearly : store.monthly }
    private var trialOnSelected: Bool { plan == .yearly && store.showsTrial }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PaywallCloseButton(action: onClose)
            }
            .padding(.horizontal, 12)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    AssetImage(name: "mascot_pointing", placeholderSymbol: "face.smiling", contentMode: .fit)
                        .frame(height: 110)
                        .accessibilityHidden(true)
                    Text(headline)
                        .appFont(30, .bold)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("paywall.title")
                    if store.yearly != nil && store.monthly != nil {
                        plans
                    } else {
                        PricesUnavailable()
                    }
                    benefits
                    if trialOnSelected, let days = store.trialDays, let price = store.pricePerPeriod(store.yearly) {
                        TrialTimeline(trialDays: days, price: price)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            VStack(spacing: 6) {
                PrimaryButton(title: buttonTitle, isLoading: store.isPurchasing,
                              isEnabled: selectedProduct != nil && !store.isPurchasing) {
                    onBuy(selectedProduct)
                }
                .accessibilityIdentifier("paywall.buy")
                if let price = store.pricePerPeriod(selectedProduct) {
                    // The amount that will be billed, right under the button.
                    Text(trialOnSelected ? String(localized: "then \(price)") : price)
                        .appFont(17, .semibold)
                        .foregroundStyle(palette.textPrimary)
                }
                PaywallFooter(link: $link, onRestore: onRestore)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .countUp($count, after: 0.3)
    }

    private var headline: String {
        switch model.paywallReason {
        case .onboarding?:
            let name = model.profile.trimmedName
            return name.isEmpty ? String(localized: "Your plan is ready") : String(localized: "Your plan is ready, \(name)")
        case .unlockLimit?:
            return String(localized: "You've used your \(Brand.freeUnlocks) free unlocks")
        case .practice?:
            return String(localized: "Practice anytime with \(Brand.subscriptionGroupName)")
        default:
            return Brand.subscriptionGroupName
        }
    }

    private var buttonTitle: String {
        if trialOnSelected, let days = store.trialDays {
            return String(localized: "Start \(days)-day free trial")
        }
        if let price = store.pricePerPeriod(selectedProduct) {
            return String(localized: "Subscribe for \(price)")
        }
        return String(localized: "Subscribe")
    }

    private var plans: some View {
        VStack(spacing: 12) {
            PlanCard(title: String(localized: "Yearly"),
                     price: store.pricePerPeriod(store.yearly) ?? "",
                     counting: store.countingPrice(store.yearly), count: count,
                     detail: store.showsTrial ? store.trialDays.map { String(localized: "\($0)-day free trial") } : nil,
                     badge: yearlyBadge,
                     selected: plan == .yearly) { plan = .yearly }
                .accessibilityIdentifier("paywall.plan.yearly")
            PlanCard(title: String(localized: "Monthly"),
                     price: store.pricePerPeriod(store.monthly) ?? "",
                     counting: store.countingPrice(store.monthly), count: count,
                     detail: nil, badge: nil,
                     selected: plan == .monthly) { plan = .monthly }
                .accessibilityIdentifier("paywall.plan.monthly")
        }
    }

    /// "BEST VALUE · $3.33/month · Save 67%" (all computed from StoreKit prices).
    private var yearlyBadge: String {
        var parts = [String(localized: "BEST VALUE")]
        if let perMonth = store.yearlyMonthlyEquivalent { parts.append(String(localized: "\(perMonth)/month")) }
        if let save = store.yearlySavingsPercent { parts.append(String(localized: "Save \(save)%")) }
        return parts.joined(separator: " · ")
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("lock.open.fill", "Unlimited unlocks")
            benefit("puzzlepiece.fill", "All 4 puzzle games + daily puzzle")
            benefit("flame.fill", "Streaks, stats and widgets")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private func benefit(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .appFont(17, .semibold)
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            Text(text).appFont(17, .medium).foregroundStyle(palette.textPrimary)
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    var counting: CountingPrice?
    var count = CountUpState()
    let detail: String?
    let badge: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { action() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let badge {
                    Text(badge)
                        .appFont(12, .heavy)
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(palette.accent, in: Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                HStack(alignment: .center, spacing: 12) {
                    RadioMark(isSelected: selected)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                        if let detail {
                            Text(detail).appFont(14).foregroundStyle(palette.textSecondary)
                        }
                    }
                    Spacer()
                    Group {
                        if let counting {
                            CountingText(value: counting.value * count.progress, final: counting.value,
                                         format: counting.format, landed: count.landed)
                        } else {
                            Text(price)
                        }
                    }
                        .appFont(19, .bold)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? palette.accent : palette.separator, lineWidth: selected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// "Today: full access" → "Day 5: we'll remind you" → "Day 7: you're billed $39.99/year, cancel anytime before".
private struct TrialTimeline: View {
    let trialDays: Int
    let price: String
    @Environment(\.palette) private var palette

    private var reminderDay: Int { max(1, trialDays - Brand.trialReminderDaysBeforeEnd) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("lock.open.fill", String(localized: "Today: full access"), last: false)
            row("bell.fill", String(localized: "Day \(reminderDay): we'll remind you"), last: false)
            row("creditcard.fill", String(localized: "Day \(trialDays): you're billed \(price), cancel anytime before"), last: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
        .accessibilityElement(children: .combine)
    }

    private func row(_ symbol: String, _ text: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .appFont(14, .bold)
                    .foregroundStyle(palette.onAccent)
                    .frame(width: 30, height: 30)
                    .background(palette.accent, in: Circle())
                if !last {
                    Rectangle().fill(palette.accent.opacity(0.35)).frame(width: 3, height: 22)
                }
            }
            .accessibilityHidden(true)
            Text(text)
                .appFont(16, .medium)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
        }
    }
}

// MARK: - Exit offer (shown once)

private struct ExitOfferScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Binding var link: URL?
    let onBuy: () -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    private var store: Store { model.store }
    @State private var count = CountUpState()

    var body: some View {
        ZStack {
            Color.paywallCream.ignoresSafeArea()
            Starburst().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    PaywallCloseButton(action: onClose)
                }
                .padding(.horizontal, 12)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        AssetImage(name: "mascot_pointing", placeholderSymbol: "face.smiling", contentMode: .fit)
                            .frame(height: 120)
                            .accessibilityHidden(true)
                        if let percent = store.offerDiscountPercent,
                           let offerPrice = store.pricePerPeriod(store.yearlyOffer),
                           let regular = store.pricePerPeriod(store.yearly) {
                            CountingText(value: Double(percent) * count.progress, final: Double(percent),
                                         format: { String(localized: "\(Int($0.rounded()))% off your first year") },
                                         landed: count.landed)
                                .appFont(34, .black, design: .rounded)
                                .foregroundStyle(Color.brandDeep)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("paywall.offer.title")
                            Text("This offer is only shown once.")
                                .appFont(17)
                                .foregroundStyle(Color.textSecondary)
                            VStack(spacing: 6) {
                                Text(regular)
                                    .appFont(17)
                                    .strikethrough()
                                    .foregroundStyle(Color.textSecondary)
                                    .accessibilityLabel(String(localized: "Regular price \(regular)"))
                                Group {
                                    if let counting = store.countingPrice(store.yearlyOffer) {
                                        CountingText(value: counting.value * count.progress, final: counting.value,
                                                     format: counting.format, landed: count.landed)
                                    } else {
                                        Text(offerPrice)
                                    }
                                }
                                    .appFont(36, .bold)
                                    .foregroundStyle(Color.textPrimary)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                Text(Brand.subscriptionGroupName + " · " + String(localized: "Yearly"))
                                    .appFont(15, .semibold)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color.brand.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                            )
                            Text("Billed \(store.yearlyOffer?.displayPrice ?? offerPrice) today, then \(offerPrice). No free trial with this offer.")
                                .appFont(15)
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            PricesUnavailable()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                VStack(spacing: 6) {
                    PrimaryButton(title: String(localized: "Claim my discount"), isLoading: store.isPurchasing,
                                  isEnabled: store.yearlyOffer != nil && !store.isPurchasing, action: onBuy)
                        .accessibilityIdentifier("paywall.offer.buy")
                    if let offerPrice = store.pricePerPeriod(store.yearlyOffer) {
                        Text(offerPrice).appFont(17, .semibold).foregroundStyle(Color.textPrimary)
                    }
                    PaywallFooter(link: $link, onRestore: onRestore)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .environment(\.colorScheme, .light)
        .environment(\.palette, .classic)
        .countUp($count, after: 0.3)
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
