import SwiftUI

/// Main app with the custom floating tab bar (Settings · Puzzles · Feedback).
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
            SettingsTab()
                .opacity(model.selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(model.selectedTab == .settings)
                .accessibilityHidden(model.selectedTab != .settings)
            PuzzlesTab()
                .opacity(model.selectedTab == .puzzles ? 1 : 0)
                .allowsHitTesting(model.selectedTab == .puzzles)
                .accessibilityHidden(model.selectedTab != .puzzles)
            FeedbackTab()
                .opacity(model.selectedTab == .feedback ? 1 : 0)
                .allowsHitTesting(model.selectedTab == .feedback)
                .accessibilityHidden(model.selectedTab != .feedback)
            FloatingTabBar(selected: Binding(get: { model.selectedTab }, set: { model.selectedTab = $0 }))
                .padding(.bottom, 4)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .screenBackground()
    }
}

struct FloatingTabBar: View {
    @Binding var selected: MainTab
    @Environment(\.palette) private var palette
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            item(.settings, title: "Settings") { color in AnyView(TogglePillsIcon(color: color, size: 26)) }
            item(.puzzles, title: "Puzzles") { color in
                AnyView(Image(systemName: "puzzlepiece.fill").appFont(24).foregroundStyle(color))
            }
            item(.feedback, title: "Feedback") { color in AnyView(ChatBubblesIcon(color: color, size: 28)) }
        }
        .padding(6)
        .background(palette.card, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        .padding(.bottom, 16)
    }

    private func item(_ tab: MainTab, title: String, icon: (Color) -> AnyView) -> some View {
        let isSelected = selected == tab
        let color = isSelected ? palette.accent : palette.textPrimary
        return Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { selected = tab }
        } label: {
            VStack(spacing: 3) {
                icon(color).frame(height: 28)
                Text(LocalizedStringKey(title)).appFont(13, .semibold).foregroundStyle(color)
            }
            .frame(width: 104, height: 60)
            .background {
                if isSelected {
                    Capsule().fill(palette.fieldFill).matchedGeometryEffect(id: "tab", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Wordmark header row used at the top of tab screens.
struct TabHeader: View {
    var body: some View {
        HStack {
            Wordmark(size: 34)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// Custom push-screen header: back button, centred title, optional trailing view.
struct PushHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Text(LocalizedStringKey(title))
                .appFont(19, .semibold)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                BackButton(action: onBack)
                Spacer()
                trailing()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .frame(height: 64)
    }
}

extension PushHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}
