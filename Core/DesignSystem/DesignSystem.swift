import SwiftUI
import UIKit

enum DS {
    enum Spacing {
        static let space0: CGFloat = 0
        static let space1: CGFloat = 4
        static let space2: CGFloat = 8
        static let space3: CGFloat = 12
        static let space4: CGFloat = 16
        static let space5: CGFloat = 20
        static let space6: CGFloat = 24
        static let space8: CGFloat = 32
        static let space10: CGFloat = 40
        static let space12: CGFloat = 48
        static let space16: CGFloat = 64
        static let space20: CGFloat = 80
        static let space24: CGFloat = 96
    }

    enum Radius {
        static let none: CGFloat = 0
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9_999
    }

    enum Motion {
        static let fast: Double = 0.1
        static let normal: Double = 0.2
        static let slow: Double = 0.3
        static let slower: Double = 0.5

        static let easeDefault = Animation.timingCurve(0.4, 0, 0.2, 1, duration: normal)
        static let easeOut = Animation.timingCurve(0, 0, 0.2, 1, duration: normal)
    }

    enum Typography {
        enum Style {
            case displayXL
            case display
            case heading1
            case heading2
            case heading3
            case bodyLG
            case body
            case bodySM
            case caption
            case overline
            case buttonSM
            case buttonMD
            case buttonLG
        }

        struct Attributes {
            let size: CGFloat
            let lineHeight: CGFloat
            let weight: Font.Weight
            let tracking: CGFloat
        }

        static func attributes(for style: Style) -> Attributes {
            switch style {
            case .displayXL: return .init(size: 48, lineHeight: 56, weight: .bold, tracking: 0)
            case .display: return .init(size: 40, lineHeight: 48, weight: .bold, tracking: 0)
            case .heading1: return .init(size: 32, lineHeight: 40, weight: .semibold, tracking: 0)
            case .heading2: return .init(size: 24, lineHeight: 32, weight: .semibold, tracking: 0)
            case .heading3: return .init(size: 20, lineHeight: 28, weight: .semibold, tracking: 0)
            case .bodyLG: return .init(size: 18, lineHeight: 28, weight: .regular, tracking: 0)
            case .body: return .init(size: 16, lineHeight: 24, weight: .regular, tracking: 0)
            case .bodySM: return .init(size: 14, lineHeight: 20, weight: .regular, tracking: 0)
            case .caption: return .init(size: 12, lineHeight: 16, weight: .regular, tracking: 0)
            case .overline: return .init(size: 11, lineHeight: 16, weight: .semibold, tracking: 0.5)
            case .buttonSM: return .init(size: 13, lineHeight: 16, weight: .medium, tracking: 0)
            case .buttonMD: return .init(size: 14, lineHeight: 20, weight: .medium, tracking: 0)
            case .buttonLG: return .init(size: 18, lineHeight: 26, weight: .medium, tracking: 0)
            }
        }

        static func usesHeadingFamily(_ style: Style) -> Bool {
            switch style {
            case .displayXL, .display, .heading1, .heading2, .heading3:
                return true
            default:
                return false
            }
        }
    }

    enum ColorToken {
        // MARK: Backgrounds
        static let bgPrimary = Color.dynamic(light: 0xFFFAF6, dark: 0x121220)       // snow
        static let bgSecondary = Color.dynamic(light: 0xF5F2EF, dark: 0x222236)     // cloud
        static let bgTertiary = Color.dynamic(light: 0xFFF4EC, dark: 0x1A1A2E)      // warmWhite

        // MARK: Borders
        static let borderDefault = Color.dynamic(light: 0xE8E4E0, dark: 0x2E2E44)   // mist
        static let borderStrong = Color.dynamic(light: 0xD5D0CB, dark: 0x3E3E58)

        // MARK: Text
        static let textPrimary = Color.dynamic(light: 0x1E1E2A, dark: 0xFFFAF6)     // ink / snow
        static let textSecondary = Color.dynamic(light: 0x4A4A5A, dark: 0xB0B0BC)   // slate
        static let textTertiary = Color.dynamic(light: 0x8E8E9A, dark: 0x6E6E80)    // fog

        // MARK: Primary (paprika)
        static let primary = Color.dynamic(light: 0xE24B2E, dark: 0xF06B52)
        static let primaryHover = Color.hex(0xF06B52)                                // paprikaSoft
        static let primaryLight = Color.dynamic(light: 0xE24B2E, lightAlpha: 0.08, dark: 0xE24B2E, darkAlpha: 0.08) // paprikaGlow

        // MARK: Semantic status
        static let success = Color.hex(0x2DB87A)                                     // basil
        static let successLight = Color.dynamic(light: 0xC8F0DD, dark: 0x2DB87A, darkAlpha: 0.15) // mint

        // MARK: Accent (basil green)
        static let accent = Color.dynamic(light: 0x2DB87A, dark: 0x3DCF8E)
        static let accentHover = Color.hex(0x3DCF8E)
        static let accentLight = Color.dynamic(light: 0x2DB87A, lightAlpha: 0.10, dark: 0x2DB87A, darkAlpha: 0.10)
        static let warning = Color.hex(0xF5A623)                                     // turmeric
        static let warningLight = Color.dynamic(light: 0xFFF0B8, dark: 0xF7D94E, darkAlpha: 0.12) // sunshine
        static let error = Color.dynamic(light: 0xE24B2E, dark: 0xF06B52)            // paprika
        static let errorLight = Color.dynamic(light: 0xFFD5C2, dark: 0xE24B2E, darkAlpha: 0.15) // peach
        static let info = Color.hex(0x3B82C4)                                        // ocean
        static let infoLight = Color.dynamic(light: 0xD6E8F7, dark: 0x3B82C4, darkAlpha: 0.15)

        // MARK: Brand accents
        static let midnight = Color.hex(0x1A1A2E)
        static let berry = Color.hex(0xB83D8A)
        static let lemon = Color.hex(0xF7D94E)
        static let ocean = Color.hex(0x3B82C4)
        static let peach = Color.hex(0xFFD5C2)
        static let mint = Color.hex(0xC8F0DD)
        static let lavender = Color.hex(0xE4D4F4)
        static let sunshine = Color.hex(0xFFF0B8)
    }
}

enum AppButtonSize {
    case sm
    case md
    case lg

    var height: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 40
        case .lg: return 48
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 16
        case .lg: return 24
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .sm: return 80
        case .md: return 100
        case .lg: return 120
        }
    }

    var textStyle: DS.Typography.Style {
        switch self {
        case .sm: return .buttonSM
        case .md: return .buttonMD
        case .lg: return .buttonLG
        }
    }
}

enum AppInputSize {
    case sm
    case md
    case lg

    var height: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 40
        case .lg: return 48
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 10
        case .md: return 12
        case .lg: return 16
        }
    }

    var textStyle: DS.Typography.Style {
        switch self {
        case .sm, .md: return .bodySM
        case .lg: return .body
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var size: AppButtonSize = .md
    var fullWidth = false
    var backgroundColor: Color = DS.ColorToken.primary
    var pressedBackgroundColor: Color = DS.ColorToken.primaryHover
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(size.textStyle)
            .foregroundStyle(foregroundColor)
            .frame(minWidth: size.minimumWidth)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: max(44, size.height))
            .padding(.vertical, DS.Spacing.space2)
            .padding(.horizontal, size.horizontalPadding)
            .background(configuration.isPressed ? pressedBackgroundColor : backgroundColor)
            .clipShape(Capsule())
            .animation(DS.Motion.easeDefault, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var size: AppButtonSize = .md
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(size.textStyle)
            .foregroundStyle(DS.ColorToken.textPrimary)
            .frame(minWidth: size.minimumWidth)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: max(44, size.height))
            .padding(.vertical, DS.Spacing.space2)
            .padding(.horizontal, size.horizontalPadding)
            .background(DS.ColorToken.bgPrimary)
            .overlay(
                Capsule()
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(DS.Motion.easeDefault, value: configuration.isPressed)
    }
}

struct AppInputFieldStyle: TextFieldStyle {
    var size: AppInputSize = .md

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .appTextStyle(size.textStyle)
            .foregroundStyle(DS.ColorToken.textPrimary)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: max(44, size.height))
            .background(DS.ColorToken.bgPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
    }
}

extension View {
    func appTextStyle(_ style: DS.Typography.Style) -> some View {
        let attributes = DS.Typography.attributes(for: style)
        let isHeading = DS.Typography.usesHeadingFamily(style)
        let font: Font

        if isHeading,
           UIFont(name: "CalSans-Regular", size: attributes.size) != nil {
            font = .custom("CalSans-Regular", size: attributes.size)
        } else {
            font = .custom("Satoshi Variable", size: attributes.size).weight(attributes.weight)
        }

        return self
            .font(font)
            .lineSpacing(max(0, attributes.lineHeight - attributes.size))
            .kerning(isHeading ? 0 : attributes.tracking)
    }
}

private extension Color {
    static func hex(_ hex: Int, alpha: Double = 1.0) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    static func dynamic(light: Int, lightAlpha: Double = 1.0, dark: Int, darkAlpha: Double = 1.0) -> Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.hex(dark, alpha: darkAlpha)
            }
            return UIColor.hex(light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    static func hex(_ hex: Int, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - SVG Icon View

struct SVGIcon: View {
    let pathData: String
    let size: CGFloat
    let strokeWidth: CGFloat

    init(_ pathData: String, size: CGFloat = 24, strokeWidth: CGFloat = 2) {
        self.pathData = pathData
        self.size = size
        self.strokeWidth = strokeWidth
    }

    var body: some View {
        SVGPathShape(pathData: pathData)
            .stroke(
                style: StrokeStyle(
                    lineWidth: strokeWidth * (size / 24),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
    }
}

private struct SVGPathShape: Shape {
    let pathData: String

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        let tokens = tokenize(pathData)
        var i = 0
        var current = CGPoint.zero

        while i < tokens.count {
            switch tokens[i] {
            case "M":
                let x = num(tokens[i + 1]) * scale
                let y = num(tokens[i + 2]) * scale
                current = CGPoint(x: x, y: y)
                path.move(to: current)
                i += 3
            case "L":
                let x = num(tokens[i + 1]) * scale
                let y = num(tokens[i + 2]) * scale
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
                i += 3
            case "H":
                let x = num(tokens[i + 1]) * scale
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
                i += 2
            case "V":
                let y = num(tokens[i + 1]) * scale
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
                i += 2
            case "C":
                let cp1 = CGPoint(x: num(tokens[i + 1]) * scale, y: num(tokens[i + 2]) * scale)
                let cp2 = CGPoint(x: num(tokens[i + 3]) * scale, y: num(tokens[i + 4]) * scale)
                let end = CGPoint(x: num(tokens[i + 5]) * scale, y: num(tokens[i + 6]) * scale)
                path.addCurve(to: end, control1: cp1, control2: cp2)
                current = end
                i += 7
            case "Z":
                path.closeSubpath()
                i += 1
            default:
                i += 1
            }
        }

        return path
    }

    private func num(_ str: String) -> CGFloat {
        CGFloat(Double(str) ?? 0)
    }

    private func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var buf = ""

        for ch in data {
            if "MLHVCSQTAZ".contains(ch) || "mlhvcsqtaz".contains(ch) {
                if !buf.isEmpty {
                    tokens.append(contentsOf: splitNumbers(buf))
                    buf = ""
                }
                tokens.append(String(ch))
            } else {
                buf.append(ch)
            }
        }

        if !buf.isEmpty {
            tokens.append(contentsOf: splitNumbers(buf))
        }

        return tokens
    }

    private func splitNumbers(_ str: String) -> [String] {
        var results: [String] = []
        var current = ""

        for ch in str {
            if ch == "," || ch == " " || ch == "\t" || ch == "\n" {
                if !current.isEmpty {
                    results.append(current)
                    current = ""
                }
            } else if ch == "-" && !current.isEmpty && !current.hasSuffix("e") {
                results.append(current)
                current = String(ch)
            } else {
                current.append(ch)
            }
        }

        if !current.isEmpty {
            results.append(current)
        }

        return results
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Tab Icon Path Data

enum TabIconPath {
    static let pantry = "M21.6003 6.29992L2.40091 6.29964L2.39966 6.29998M21.6003 6.29992L21.5997 19.616C21.5997 20.8774 20.5577 21.9 19.2724 21.9H4.72693C3.44161 21.9 2.39966 20.8774 2.39966 19.616V6.29998M21.6003 6.29992L17.7511 2.45145C17.5261 2.2264 17.2209 2.09998 16.9026 2.09998H7.09671C6.77845 2.09998 6.47323 2.2264 6.24819 2.45145L2.39966 6.29998M15.5997 9.89998C15.5997 11.8882 13.9879 13.5 11.9997 13.5C10.0114 13.5 8.39966 11.8882 8.39966 9.89998"

    static let recipe = "M8.57145 2.40002V21.6M17.4857 10.6286H12.6857M17.4857 6.51431H12.6857M5.14288 6.51431H2.40002M5.14288 10.6286H2.40002M5.14288 14.7429H2.40002M6.51431 21.6H18.8572C20.372 21.6 21.6 20.372 21.6 18.8572V5.14288C21.6 3.62804 20.372 2.40002 18.8572 2.40002H6.51431C4.99947 2.40002 3.77145 3.62804 3.77145 5.14288V18.8572C3.77145 20.372 4.99947 21.6 6.51431 21.6Z"

    static let macro = "M9.05647 21V11.024C9.05647 10.4717 9.50419 10.024 10.0565 10.024H14.1147C14.667 10.024 15.1147 10.4717 15.1147 11.024V21M9.05647 21L9.05792 16.6803C9.0581 16.1279 8.61033 15.68 8.05791 15.68H4C3.44772 15.68 3 16.1277 3 16.68V20C3 20.5523 3.44772 21 4 21H9.05647ZM9.05647 21H15.1147M15.1147 21V4C15.1147 3.44772 15.5624 3 16.1147 3H20C20.5523 3 21 3.44772 21 4V20C21 20.5523 20.5523 21 20 21H15.1147Z"

    static let profile = "M12 11C14.2091 11 16 9.20914 16 7C16 4.79086 14.2091 3 12 3C9.79086 3 8 4.79086 8 7C8 9.20914 9.79086 11 12 11ZM12 11C7.02944 11 3 14.1341 3 18V21M12 11C16.9706 11 21 14.1341 21 18V21"
}
