import SwiftUI

/// A real app's icon as it looks on the home screen: the brand glyph (vector asset `logo_<name>`, from
/// simple-icons) on its brand-coloured rounded square (continuous corners, radius ≈ 22% of the size).
/// Unknown names fall back to a neutral grey app tile.
struct BrandAppIcon: View {
    let name: String
    var size: CGFloat = 52

    private struct Style {
        let background: AnyShapeStyle
        let glyph: Color
    }

    private var style: Style {
        switch name {
        case "tiktok", "x", "threads": return Style(background: AnyShapeStyle(Color.black), glyph: .white)
        case "instagram":
            return Style(background: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xFEDA75), Color(hex: 0xFA7E1E), Color(hex: 0xD62976), Color(hex: 0x962FBF), Color(hex: 0x4F5BD5)],
                startPoint: .bottomLeading, endPoint: .topTrailing)), glyph: .white)
        case "youtube": return Style(background: AnyShapeStyle(Color(hex: 0xFF0000)), glyph: .white)
        case "snapchat": return Style(background: AnyShapeStyle(Color(hex: 0xFFFC00)), glyph: .black)
        case "reddit": return Style(background: AnyShapeStyle(Color(hex: 0xFF4500)), glyph: .white)
        case "facebook": return Style(background: AnyShapeStyle(Color(hex: 0x1877F2)), glyph: .white)
        case "appstore": return Style(background: AnyShapeStyle(Color(hex: 0x0D96F6)), glyph: .white)
        default: return Style(background: AnyShapeStyle(Color(hex: 0x8E8E93)), glyph: .white)
        }
    }

    private var hasLogo: Bool { UIImage(named: "logo_\(name)") != nil }

    var body: some View {
        let s = style
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(s.background)
            .frame(width: size, height: size)
            .overlay {
                Group {
                    if hasLogo {
                        Image("logo_\(name)")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app.fill").resizable().scaledToFit()
                    }
                }
                .foregroundStyle(s.glyph)
                .frame(width: size * 0.56, height: size * 0.56)
            }
            .accessibilityHidden(true)
    }
}
