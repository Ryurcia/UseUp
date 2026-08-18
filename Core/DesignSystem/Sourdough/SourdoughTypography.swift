import SwiftUI

/// "Sourdough" design system v1 typography (§3).
///
/// Strict division of labor: Newsreader (serif) for anything a person wrote or cooked
/// (titles, prose, empty states); Figtree (sans) for anything the database knows
/// (data, lists, counts, chips, buttons, tab bars). Never mix beyond the 9 named styles below.
extension Sourdough {
    enum FontFamily: String {
        case figtree = "Figtree"
        case newsreader = "Newsreader"
    }

    enum Typography {
        /// The 9 fixed block styles. "Newsreader Italic" (inline quantities-in-prose only) is
        /// intentionally not a case here — it's an inline helper, see `SDFont.italic(_:size:)`.
        enum Style: CaseIterable {
            case display      // Onboarding, empty states
            case title1       // Screen titles, recipe names
            case title2       // Card headers, sheet titles
            case sectionHead  // List group headers
            case rowTitle     // Pantry item names, list rows
            case body         // Method steps, descriptions
            case subhead      // Row secondary line
            case numeric      // Counts, dates, quantities
            case caption      // Chips, tab labels, badges
        }

        struct Attributes {
            let family: FontFamily
            let size: CGFloat
            let lineHeight: CGFloat
            let weight: CGFloat        // variable-font `wght` axis value
            let tracking: CGFloat      // fraction of size (e.g. -0.02 = -2%)
            let uppercase: Bool
            let dynamicTypeStyle: UIFont.TextStyle
        }

        static func attributes(for style: Style) -> Attributes {
            switch style {
            case .display:
                return Attributes(family: .newsreader, size: 40, lineHeight: 42, weight: 400, tracking: -0.02, uppercase: false, dynamicTypeStyle: .largeTitle)
            case .title1:
                return Attributes(family: .newsreader, size: 30, lineHeight: 34, weight: 400, tracking: -0.015, uppercase: false, dynamicTypeStyle: .title1)
            case .title2:
                return Attributes(family: .newsreader, size: 22, lineHeight: 28, weight: 500, tracking: 0, uppercase: false, dynamicTypeStyle: .title2)
            case .sectionHead:
                return Attributes(family: .figtree, size: 12, lineHeight: 16, weight: 700, tracking: 0.12, uppercase: true, dynamicTypeStyle: .headline)
            case .rowTitle:
                return Attributes(family: .figtree, size: 16, lineHeight: 22, weight: 600, tracking: 0, uppercase: false, dynamicTypeStyle: .body)
            case .body:
                return Attributes(family: .figtree, size: 15, lineHeight: 24, weight: 400, tracking: 0, uppercase: false, dynamicTypeStyle: .body)
            case .subhead:
                return Attributes(family: .figtree, size: 13, lineHeight: 18, weight: 400, tracking: 0, uppercase: false, dynamicTypeStyle: .subheadline)
            case .numeric:
                return Attributes(family: .figtree, size: 13, lineHeight: 16, weight: 600, tracking: 0, uppercase: false, dynamicTypeStyle: .footnote)
            case .caption:
                return Attributes(family: .figtree, size: 11, lineHeight: 14, weight: 500, tracking: 0, uppercase: false, dynamicTypeStyle: .caption1)
            }
        }
    }
}

// MARK: - Font construction

extension Sourdough {
    enum SDFont {
        // 4-char axis tags as UInt32 big-endian, per the OpenType/CoreText variation convention.
        private static let wghtTag: UInt32 = 0x77676874 // 'wght'
        private static let opszTag: UInt32 = 0x6F70737A // 'opsz'
        private static let variationKey = UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute")

        /// Builds a `UIFont` by dialing the bundled variable font's axes directly, rather than
        /// relying on named-instance PostScript names resolving via `UIFont(name:)` (not
        /// guaranteed across iOS versions, and Newsreader's named instances all pin opsz=16pt —
        /// wrong for our "opsz tracks point size" requirement).
        static func uiFont(family: FontFamily, size: CGFloat, weight: CGFloat, italic: Bool = false) -> UIFont {
            var variations: [UInt32: CGFloat] = [wghtTag: weight]
            if family == .newsreader {
                variations[opszTag] = size // "Enable optical sizing (opsz set to point size)"
            }
            let attributes: [UIFontDescriptor.AttributeName: Any] = [
                .family: family.rawValue,
                variationKey: variations
            ]
            var descriptor = UIFontDescriptor(fontAttributes: attributes)
            if italic, let italicDescriptor = descriptor.withSymbolicTraits(.traitItalic) {
                // No bundled true-italic Newsreader face — CoreText synthesizes an oblique.
                descriptor = italicDescriptor
            }
            let font = UIFont(descriptor: descriptor, size: size)
            guard font.familyName.caseInsensitiveCompare(family.rawValue) == .orderedSame else {
                return fallbackFont(family: family, size: size, weight: weight, italic: italic)
            }
            return font
        }

        /// Fallback path per spec §1: New York → Georgia for serif (Newsreader), SF Pro → system-ui
        /// for sans (Figtree). Only reached if the bundled variable font can't be resolved.
        private static func fallbackFont(family: FontFamily, size: CGFloat, weight: CGFloat, italic: Bool) -> UIFont {
            let uiWeight: UIFont.Weight
            switch weight {
            case ..<450: uiWeight = .regular
            case ..<550: uiWeight = .medium
            case ..<650: uiWeight = .semibold
            default: uiWeight = .bold
            }
            var base: UIFont
            switch family {
            case .figtree:
                base = .systemFont(ofSize: size, weight: uiWeight)
            case .newsreader:
                if let serifDescriptor = UIFont.systemFont(ofSize: size, weight: uiWeight).fontDescriptor.withDesign(.serif) {
                    base = UIFont(descriptor: serifDescriptor, size: size) // New York
                } else {
                    base = UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size, weight: uiWeight)
                }
            }
            if italic, let italicDescriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
                base = UIFont(descriptor: italicDescriptor, size: size)
            }
            return base
        }

        /// Dynamic-Type-scaled `Font` for a named style. Figtree scales freely; Newsreader is
        /// capped at ~1.6x per §3.
        static func font(for style: Typography.Style) -> Font {
            let attrs = Typography.attributes(for: style)
            let base = uiFont(family: attrs.family, size: attrs.size, weight: attrs.weight)
            let cap = attrs.family == .newsreader ? attrs.size * 1.6 : CGFloat.greatestFiniteMagnitude
            let scaled = UIFontMetrics(forTextStyle: attrs.dynamicTypeStyle).scaledFont(for: base, maximumPointSize: cap)
            return Font(scaled as CTFont)
        }

        /// Inline Newsreader Italic for quantities embedded in prose — not a named block style.
        static func italicFont(size: CGFloat = 15) -> Font {
            let base = uiFont(family: .newsreader, size: size, weight: 400, italic: true)
            let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(for: base, maximumPointSize: size * 1.6)
            return Font(scaled as CTFont)
        }

        /// `Text("2 cups") ` styled as inline Newsreader Italic, for concatenating into prose Text.
        static func italic(_ string: String, size: CGFloat = 15) -> Text {
            Text(string).font(italicFont(size: size))
        }
    }
}

// MARK: - View modifier

extension Sourdough {
    struct TextStyleModifier: ViewModifier {
        let style: Typography.Style

        func body(content: Content) -> some View {
            let attrs = Typography.attributes(for: style)
            content
                .font(SDFont.font(for: style))
                .tracking(attrs.tracking * attrs.size)
                .lineSpacing(max(0, attrs.lineHeight - attrs.size))
                .textCase(attrs.uppercase ? .uppercase : nil)
                .foregroundStyle(style == .subhead ? Sourdough.Colors.mutedInk : Sourdough.Colors.ink)
                .modifier(TabularFiguresModifier(isNumeric: style == .numeric))
        }
    }

    /// Tabular (monospaced) figures baked into `.numeric`; apply `.monospacedDigit()` manually at
    /// call sites embedding a changing number inside any other style (countdowns, live counts).
    private struct TabularFiguresModifier: ViewModifier {
        let isNumeric: Bool
        func body(content: Content) -> some View {
            if isNumeric {
                content.monospacedDigit()
            } else {
                content
            }
        }
    }
}

extension View {
    /// Applies a named Sourdough text style — size, line height, tracking, case, and default ink
    /// color are all baked in per §3; override color afterward with `.foregroundStyle(_:)` if needed.
    func sourdoughTextStyle(_ style: Sourdough.Typography.Style) -> some View {
        modifier(Sourdough.TextStyleModifier(style: style))
    }
}
