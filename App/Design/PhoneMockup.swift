import SwiftUI

/// A phone drawn in SwiftUI: black rounded bezel, Dynamic Island, "9:41" status bar and home indicator.
struct PhoneMockup<Content: View>: View {
    var width: CGFloat = 270
    var screenColor: Color = .white
    var darkStatusBar = false
    @ViewBuilder var content: () -> Content

    private var height: CGFloat { width * 1.98 }
    private var bezel: CGFloat { width * 0.035 }
    private var outerRadius: CGFloat { width * 0.17 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color.black)
            ZStack(alignment: .top) {
                screenColor
                content()
                    .padding(.top, width * 0.16)
                    .padding(.bottom, width * 0.06)
                statusBar
                    .padding(.top, width * 0.045)
                    .padding(.horizontal, width * 0.08)
                Capsule()
                    .fill(Color.black)
                    .frame(width: width * 0.3, height: width * 0.085)
                    .padding(.top, width * 0.035)
                VStack {
                    Spacer()
                    Capsule()
                        .fill(darkStatusBar ? Color.white : Color.black)
                        .frame(width: width * 0.36, height: 4.5)
                        .padding(.bottom, width * 0.025)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: outerRadius - bezel, style: .continuous))
            .padding(bezel)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: width * 0.05, weight: .semibold))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: width * 0.042, weight: .semibold))
        }
        .foregroundStyle(darkStatusBar ? Color.white : Color.black)
        .accessibilityHidden(true)
    }
}

/// A generic rounded app icon built from an SF Symbol. No third-party logos.
struct MockAppIcon: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 52

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }

    static func social(size: CGFloat = 52) -> MockAppIcon {
        MockAppIcon(symbol: "camera.circle", colors: [Color(hex: 0x8A3AB9), Color(hex: 0xE95950), Color(hex: 0xFCCC63)], size: size)
    }
}
