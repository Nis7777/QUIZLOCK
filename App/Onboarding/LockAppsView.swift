import SwiftUI

/// S10: "Lock your apps." — how-to mock, selected apps, and the system picker.
struct LockAppsView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenTitle(title: "Lock your apps.",
                                subtitle: "Select the apps that distract you the most, the ones you open on autopilot.",
                                size: 36)
                    if model.lockItems.isEmpty {
                        PickerHowToMock()
                            .padding(.horizontal, 20)
                        emptyCard
                    } else {
                        selectedCard
                    }
                    Button {
                        Haptics.tap()
                        showPicker = true
                    } label: {
                        Label("Add Apps to Lock", systemImage: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(palette.accent.opacity(0.35), lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 20)
                    Text(model.lockItems.isEmpty ? "You can add apps later in Settings." : "You can update this later in Settings.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.accentText)
                }
                .padding(.bottom, 20)
            }
            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .screenBackground()
        .appPicker(isPresented: $showPicker)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(palette.textSecondary)
            Text("No locks yet").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.textPrimary)
            Text("Choose an app to get started.").font(.system(size: 15)).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22)
        .padding(.horizontal, 20)
    }

    private var selectedCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.lockItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, 62) }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        LockItemLabel(item: item)
                        Text("Ready to lock")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textSecondary)
                            .padding(.leading, 46)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(palette.accent)
                }
                .padding(.vertical, 10)
            }
        }
        .card()
        .padding(.horizontal, 20)
        .transition(.opacity)
    }
}

/// How-to mock of the system picker, drawn in SwiftUI (no screenshot).
struct PickerHowToMock: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(hex: 0x0A84FF), in: Capsule())
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x0A84FF))
                    MockAppIcon.social(size: 22)
                    Text("Social").font(.system(size: 14, weight: .semibold))
                    Text("— Social Networking").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    Spacer()
                }
                .foregroundStyle(Color.textPrimary)
                .padding(10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Social")
                    Spacer()
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .padding(8)
                .background(Color(hex: 0xE3E3E8), in: RoundedRectangle(cornerRadius: 9))
                keyboard
            }
            .padding(12)
            .background(Color(hex: 0xF0F0F4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("Add apps → Search → Select → Done")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("How to: Add apps, search, select, then Done")
    }

    private var keyboard: some View {
        VStack(spacing: 5) {
            ForEach(["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"], id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(Array(row), id: \.self) { ch in
                        Text(String(ch))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: 24)
                            .frame(height: 22)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(6)
        .background(Color(hex: 0xD1D3D9), in: RoundedRectangle(cornerRadius: 10))
    }
}
