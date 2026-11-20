import SwiftUI

/// S07: "Enjoy your feed." with a grey wireframe social feed.
struct EnjoyFeedView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            ScreenTitle(title: "Enjoy your feed.", subtitle: "You've earned it!", size: 34)
            GeometryReader { geo in
                let width = min(geo.size.width * 0.66, geo.size.height / 2.05)
                PhoneMockup(width: width) {
                    feed(width: width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 18)
            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .screenBackground()
    }

    private func feed(width: CGFloat) -> some View {
        let grey = Color(hex: 0xD8D8DD)
        return VStack(alignment: .leading, spacing: width * 0.035) {
            HStack {
                Text("Instagram").font(.system(size: width * 0.07, weight: .bold, design: .serif)).italic()
                Spacer()
                Image(systemName: "heart")
                Image(systemName: "paperplane")
            }
            .font(.system(size: width * 0.06))
            .foregroundStyle(Color.textPrimary)
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: width * 0.025) {
                    HStack(spacing: width * 0.03) {
                        Circle().fill(grey).frame(width: width * 0.09, height: width * 0.09)
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(grey).frame(width: width * 0.3, height: width * 0.025)
                            Capsule().fill(grey).frame(width: width * 0.18, height: width * 0.02)
                        }
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xECECEF))
                        Image(systemName: "photo").font(.system(size: width * 0.1)).foregroundStyle(Color(hex: 0xB8B8BE))
                    }
                    .frame(height: width * 0.48)
                    HStack(spacing: width * 0.04) {
                        Image(systemName: "heart")
                        Image(systemName: "bubble.right")
                        Image(systemName: "paperplane")
                        Spacer()
                        Image(systemName: "bookmark")
                    }
                    .font(.system(size: width * 0.05))
                    .foregroundStyle(Color(hex: 0x9A9AA0))
                }
            }
            Spacer(minLength: 0)
            HStack {
                ForEach(["house.fill", "magnifyingglass", "plus.app", "play.rectangle", "person.circle"], id: \.self) { s in
                    Image(systemName: s).frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: width * 0.055))
            .foregroundStyle(Color(hex: 0x6E6E73))
        }
        .padding(.horizontal, width * 0.05)
        .accessibilityHidden(true)
    }
}
