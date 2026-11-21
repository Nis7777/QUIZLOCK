import SwiftUI

/// "Manage apps" push screen.
struct ManageAppsView: View {
    @Binding var path: [SettingsRoute]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 0) {
            PushHeader(title: "Manage apps", onBack: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your apps and how long each stays unlocked after a puzzle.")
                        .appFont(16)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    PrimaryButton(title: "Add Apps", systemImage: "plus") { showPicker = true }
                        .padding(.horizontal, 16)
                    Button { path.append(.unlockTime) } label: {
                        InfoRow(icon: AnyView(Image(systemName: "timer").appFont(22).foregroundStyle(palette.accent)),
                                title: "Default unlock time", subtitle: model.lock.defaultDuration.localizedLabel)
                    }
                    .buttonStyle(.plain)
                    .card()
                    .padding(.horizontal, 16)

                    Button { path.append(.schedule) } label: {
                        InfoRow(icon: AnyView(Image(systemName: "calendar.badge.clock").appFont(22).foregroundStyle(palette.accent)),
                                title: "Lock schedule",
                                subtitle: model.lock.schedule?.summary ?? String(localized: "Always"))
                    }
                    .buttonStyle(.plain)
                    .card()
                    .padding(.horizontal, 16)

                    Text("Your apps · \(model.lockItems.count)")
                        .appFont(19, .semibold)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                    Text("Apps use the default time unless you choose a different one below.")
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 22)

                    if model.lockItems.isEmpty {
                        MascotEmptyState(title: "No apps locked yet",
                                         message: "Tap Add Apps to choose the apps that distract you most.")
                            .padding(.horizontal, 16)
                    }
                    ForEach(model.lockItems) { item in
                        appCard(item)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.bottom, 120)
                .animation(.selectionSpring, value: model.lockItems.map(\.id))
            }
        }
        .screenBackground()
        .appPicker(isPresented: $showPicker)
    }

    private func appCard(_ item: LockItem) -> some View {
        let override = model.lock.config(for: item.key).override
        return VStack(spacing: 0) {
            HStack {
                LockItemLabel(item: item)
                Spacer()
                Button {
                    Haptics.tap()
                    model.remove(item)
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                        .appFont(16, .medium)
                        .foregroundStyle(Color.errorRed)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 14)
            Divider()
            Button { path.append(.appUnlockTime(item.key)) } label: {
                HStack {
                    Text("Unlock time").appFont(16).foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text(override.map(\.localizedLabel) ?? String(localized: "Default · \(model.lock.defaultDuration.localizedLabel)"))
                        .appFont(15)
                        .foregroundStyle(palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .appFont(14, .semibold)
                        .foregroundStyle(Color(hex: 0xA0A0A6))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(palette.isDark ? 0 : 0.04), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}
