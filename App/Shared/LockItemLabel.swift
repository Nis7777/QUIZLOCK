import FamilyControls
import ManagedSettings
import SwiftUI

/// Shows a selected app/category/website with its real icon and name via `Label(token)`,
/// or a fake app in the Simulator.
struct LockItemLabel: View {
    let item: LockItem
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch item.kind {
            case .app(let token):
                Label(token)
            case .category(let token):
                Label(token)
            case .web(let token):
                Label(token)
            case .mock(let name):
                Label {
                    Text(name)
                } icon: {
                    BrandAppIcon(name: MockApps.logo(name), size: 30)
                }
            }
        }
        .labelStyle(LockItemLabelStyle())
        .appFont(17)
        .foregroundStyle(palette.textPrimary)
    }
}

private struct LockItemLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.icon
                .frame(width: 32, height: 32)
            configuration.title
                .lineLimit(1)
        }
    }
}

/// Presents the system FamilyActivityPicker (or a mock picker in the Simulator).
struct AppPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        if ScreenTimeService.isMock {
            content.sheet(isPresented: $isPresented) {
                MockAppPicker()
                    .environment(model)
                    .environment(\.palette, model.palette)
            }
        } else {
            content.familyActivityPicker(isPresented: $isPresented, selection: model.lockBinding(\.selection))
        }
    }
}

extension View {
    func appPicker(isPresented: Binding<Bool>) -> some View {
        modifier(AppPickerModifier(isPresented: isPresented))
    }
}

/// Simulator stand-in for FamilyActivityPicker.
struct MockAppPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MockApps.all, id: \.name) { app in
                        let selected = model.lock.mockApps.contains(app.name)
                        Button {
                            Haptics.tap()
                            model.updateLock { state in
                                if selected { state.mockApps.removeAll { $0 == app.name } } else { state.mockApps.append(app.name) }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                BrandAppIcon(name: app.logo, size: 32)
                                Text(app.name).foregroundStyle(palette.textPrimary)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .appFont(22)
                                    .foregroundStyle(selected ? Color.brand : Color(hex: 0xC7C7CC))
                            }
                        }
                    }
                } footer: {
                    Text("Simulator mock: FamilyControls isn't available here, so these are fake apps.")
                }
            }
            .navigationTitle("Choose Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
