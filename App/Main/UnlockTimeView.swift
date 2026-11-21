import SwiftUI

/// "Unlock time" push screen. With an `itemKey` it's the per-app override variant.
struct UnlockTimeView: View {
    let itemKey: String?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PushHeader(title: "Unlock time", onBack: { dismiss() }) {
                PillButton(title: "Done") { dismiss() }
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let key = itemKey, let item = model.lockItems.first(where: { $0.key == key }) {
                        LockItemLabel(item: item)
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                        DurationOptionsCard(selection: model.lock.config(for: key).override,
                                            onSelect: { model.setOverride($0, for: key) },
                                            leading: AnyView(useDefaultRow(key: key)))
                            .padding(.horizontal, 16)
                        FooterText(text: "This overrides the default for this app. Current unlocks keep their remaining time.")
                    } else {
                        DurationOptionsCard(selection: model.lock.defaultDuration,
                                            onSelect: { d in model.updateLock { $0.defaultDuration = d } })
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        FooterText(text: "The default for apps without an override. Changes apply the next time you earn an unlock; current unlocks keep their remaining time.")
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .screenBackground()
    }

    private func useDefaultRow(key: String) -> some View {
        let usingDefault = model.lock.config(for: key).override == nil
        return Button {
            Haptics.tap()
            withAnimation(.selectionSpring) { model.setOverride(nil, for: key) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use default").appFont(19, .semibold).foregroundStyle(palette.textPrimary)
                    Text(model.lock.defaultDuration.localizedLabel).appFont(15).foregroundStyle(palette.textSecondary)
                }
                Spacer()
                RadioMark(isSelected: usingDefault)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
