import SwiftUI
import UIKit
import PhosphorSwift

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

struct OutlineButtonStyle: ButtonStyle {
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
            .background(Color.clear)
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
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

    /// Standard "Report Error" alert bound to an optional error-message state — the same
    /// get/set/OK-button boilerplate was hand-rolled at every recipe/review report call site.
    func reportErrorAlert(_ error: Binding<String?>) -> some View {
        alert("Report Error", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK") { error.wrappedValue = nil }
        } message: {
            if let err = error.wrappedValue { Text(err) }
        }
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

// MARK: - Top-nav icon buttons

extension Sourdough.Colors {
    /// Warm grey circular chip behind top-nav icon buttons (notification bell, pantry search).
    /// Stays clearly distinct from the canvas in both modes (light `sunken`; a lifted grey in
    /// dark, where `sunken`'s 0.6α is too faint to read as a circle).
    static var navChip: Color { Sourdough.dynamic(light: 0xF2EDE4, dark: 0x35302C) }
}

/// A 32pt grey circular icon button for a screen's top nav — matches `NotificationBellButton`'s
/// geometry exactly (that one renders its own chip because it also carries a badge overlay).
struct NavChipButton: View {
    let icon: Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 17, height: 17)
                .foregroundStyle(Sourdough.Colors.ink)
                .frame(width: 32, height: 32)
                .background(Sourdough.Colors.navChip)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var session: AppSession

    private var alertItems: [Ingredient] {
        pantryStore.expiringAlertCandidates()
            .filter { $0.notifReadAt == nil }
    }

    private var chipFill: Color { Sourdough.Colors.navChip }

    var body: some View {
        Button {
            session.showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                (alertItems.isEmpty ? Ph.bell.regular : Ph.bell.fill)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .frame(width: 32, height: 32)
                    .background(chipFill)
                    .clipShape(Circle())

                if !alertItems.isEmpty {
                    Text("\(alertItems.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(DS.ColorToken.error)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Nav Button

struct ProfileNavButton: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Button {
            session.showProfile = true
        } label: {
            if let data = session.profileImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Ph.userCircle.fill
                    .frame(width: 24, height: 24)
                    .foregroundStyle(DS.ColorToken.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
