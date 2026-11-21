import SwiftUI

/// The primary button for onboarding and the paywall: a coral face (#FF5A36) on a 5pt darker edge
/// (#D9431F) for a 3D look. Pressing moves the face down 4pt (edge shrinks) with Motion.snappy + a
/// light haptic. Disabled: coral at 35% opacity, flat, no press.
struct ChunkyButton: View {
    enum Style { case coral, white }

    let title: String
    var style: Style = .coral
    var systemImage: String?
    var isEnabled = true
    var isLoading = false
    var shimmer = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(style == .coral ? .white : .brand)
                } else if let systemImage {
                    Image(systemName: systemImage).appFont(18, .bold)
                }
                Text(LocalizedStringKey(title)).appFont(18, .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButtonStyle(style: style, enabled: isEnabled && !isLoading, shimmer: shimmer))
        .disabled(!isEnabled || isLoading)
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    let style: ChunkyButton.Style
    let enabled: Bool
    var shimmer = false

    static let faceHeight: CGFloat = 60
    static let edge: CGFloat = 5

    private var face: Color { style == .coral ? Color(hex: 0xFF5A36) : .white }
    private var edgeColor: Color { style == .coral ? Color(hex: 0xD9431F) : Color(hex: 0xE9D3CB) }
    private var label: Color { style == .coral ? .white : Color(hex: 0xE4421F) }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .top) {
            if enabled {
                shape.fill(edgeColor)
                    .frame(height: Self.faceHeight)
                    .offset(y: Self.edge)
            }
            configuration.label
                .foregroundStyle(label)
                .frame(height: Self.faceHeight)
                .frame(maxWidth: .infinity)
                .background(shape.fill(face))
                .overlay {
                    if shimmer && enabled { shape.fill(Color.clear).shimmer().clipShape(shape) }
                }
                .offset(y: pressed ? 4 : 0)
        }
        .frame(height: Self.faceHeight + Self.edge, alignment: .top)
        .opacity(enabled ? 1 : 0.35)
        .animation(Motion.snappy, value: pressed)
        .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, now in now && enabled }
        .contentShape(shape)
    }
}
