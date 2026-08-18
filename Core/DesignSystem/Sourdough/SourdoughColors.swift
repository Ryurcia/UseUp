import SwiftUI

/// "Sourdough" design system v1 color tokens.
///
/// Usage ratio per screen (enforce at the call site, not encoded here):
/// Linen ≈60% (canvas/cards/sheets) · Ink ≈30% (copy/icons) · Sage/honey ≈8% (state, tinted only)
/// · Terracotta ≤2% (primary CTA / active tab / "use today" — never more than one per screen).
///
/// Light mode is primary; dark mode is a tinted inversion mapped from the same semantic tokens,
/// not a hand-authored second palette.
enum Sourdough {}

// MARK: - Hex helpers (file-local; independent of the legacy `DS` system's private helpers)

private extension SwiftUI.Color {
    init(sdHex hex: Int, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private extension UIColor {
    convenience init(sdHex hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Sourdough {
    /// Light/dark aware color. `highContrastLight`/`highContrastDark` are substituted when
    /// the Increase Contrast accessibility setting is on (§6/§7 override layer).
    static func dynamic(
        light: Int,
        lightAlpha: Double = 1,
        dark: Int,
        darkAlpha: Double = 1,
        highContrastLight: Int? = nil,
        highContrastDark: Int? = nil
    ) -> SwiftUI.Color {
        SwiftUI.Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            if isDark {
                if isHighContrast, let highContrastDark {
                    return UIColor(sdHex: highContrastDark)
                }
                return UIColor(sdHex: dark, alpha: darkAlpha)
            }
            if isHighContrast, let highContrastLight {
                return UIColor(sdHex: highContrastLight)
            }
            return UIColor(sdHex: light, alpha: lightAlpha)
        })
    }
}

// MARK: - Ramps (§2) — raw scale values; components should prefer `Sourdough.Colors` semantics below

extension Sourdough {
    enum Ramp {
        // Terracotta — primary (brand, actions, urgency)
        static let terracotta50 = SwiftUI.Color(sdHex: 0xFDF4EF)
        static let terracotta100 = SwiftUI.Color(sdHex: 0xF7E3D8)
        static let terracotta200 = SwiftUI.Color(sdHex: 0xEDC3AD)
        static let terracotta300 = SwiftUI.Color(sdHex: 0xE0A184)
        static let terracotta400 = SwiftUI.Color(sdHex: 0xD07F5C)
        static let terracotta500 = SwiftUI.Color(sdHex: 0xC4643F) // base
        static let terracotta600 = SwiftUI.Color(sdHex: 0xA44E2E) // ink-safe
        static let terracotta700 = SwiftUI.Color(sdHex: 0x7E3A20)
        static let terracottaDark = SwiftUI.Color(sdHex: 0xE08055) // dark-mode lifted (§6)

        // Sage — secondary (fresh state, categories, calm confirmation)
        static let sage50 = SwiftUI.Color(sdHex: 0xF3F6F0)
        static let sage100 = SwiftUI.Color(sdHex: 0xE9EEE4)
        static let sage200 = SwiftUI.Color(sdHex: 0xCFD9C6)
        static let sage300 = SwiftUI.Color(sdHex: 0xAEBDA1)
        static let sage400 = SwiftUI.Color(sdHex: 0x8B9C7C)
        static let sage500 = SwiftUI.Color(sdHex: 0x6F7F63) // base
        static let sage600 = SwiftUI.Color(sdHex: 0x56654B) // ink-safe
        static let sage700 = SwiftUI.Color(sdHex: 0x3D4936)
        static let sageDark = SwiftUI.Color(sdHex: 0x93A588)

        // Honey — accent ("use soon", highlights; ink-safe from 700 only)
        static let honey50 = SwiftUI.Color(sdHex: 0xFEF8EC)
        static let honey100 = SwiftUI.Color(sdHex: 0xFAEBCD)
        static let honey200 = SwiftUI.Color(sdHex: 0xF2D9A9)
        static let honey300 = SwiftUI.Color(sdHex: 0xE7C27D) // base
        static let honey400 = SwiftUI.Color(sdHex: 0xD7A855)
        static let honey500 = SwiftUI.Color(sdHex: 0xC99633)
        static let honey600 = SwiftUI.Color(sdHex: 0xA0752A)
        static let honey700 = SwiftUI.Color(sdHex: 0x6E5426) // ink-safe
        static let honeyDark = SwiftUI.Color(sdHex: 0xEFCF95)

        // Linen — neutral (every surface, border, text; warm-grey, never pure black/white)
        static let linen0 = SwiftUI.Color(sdHex: 0xFFFCF7)   // card
        static let linen50 = SwiftUI.Color(sdHex: 0xFBF7F1)  // canvas
        static let linen100 = SwiftUI.Color(sdHex: 0xF2EDE4) // sunken
        static let linen200 = SwiftUI.Color(sdHex: 0xEBE3D8) // hairline
        static let linen300 = SwiftUI.Color(sdHex: 0xC4BCB2) // disabled
        static let linen400 = SwiftUI.Color(sdHex: 0xA79E92) // faint
        static let linen500 = SwiftUI.Color(sdHex: 0x6B6259) // muted
        static let linen900 = SwiftUI.Color(sdHex: 0x2E2A26) // ink

        // Dark-mode surfaces/text (§6)
        static let darkCanvas = SwiftUI.Color(sdHex: 0x211E1B)
        static let darkCard = SwiftUI.Color(sdHex: 0x2B2724)
        static let darkHairline = SwiftUI.Color(sdHex: 0x3D3833)
        static let darkTextPrimary = SwiftUI.Color(sdHex: 0xF5F0E8)
        static let darkTextMuted = SwiftUI.Color(sdHex: 0xA79E92)

        // Fixed accessible values that aren't literal ramp steps (from §2/§7's exact ledger)
        static let freshLabelLight = SwiftUI.Color(sdHex: 0x47543C)  // 7.0:1 on sage100 — NOT sage600/700
        static let destructive = SwiftUI.Color(sdHex: 0x8E3A2A)      // deliberately darker than brand
        static let onFilled = SwiftUI.Color(sdHex: 0xFFF6F1)         // label on action/urgent/destructive fills

        // Dark urgent-chip inversion (§6) — a solid terracotta block reads too heavy on near-black
        static let urgentDarkTint = SwiftUI.Color(sdHex: 0x4A2A1D)
        static let urgentDarkLabel = SwiftUI.Color(sdHex: 0xFFB894)

        // Accessibility override values (§6/§7)
        static let interactiveBorderStandard = SwiftUI.Color(sdHex: 0xC4BCB2) // linen300, 2.0:1 + 44pt hit target
        static let interactiveBorderHighContrast = SwiftUI.Color(sdHex: 0x6B6259)
        static let mutedInkHighContrast = SwiftUI.Color(sdHex: 0x554E46)
        static let darkChipFillOpaque = SwiftUI.Color(sdHex: 0x3D3833) // Reduce Transparency override
    }
}

// MARK: - Semantic tokens (§2, §6) — components should reference only these, never raw hex/ramp steps directly

extension Sourdough {
    /// A freshness state's paired fill + text color. Never expose color without a day-count label
    /// alongside it at the call site — see `FreshnessChip`/`FreshnessMeter`.
    struct FreshnessStyle {
        let tint: SwiftUI.Color
        let label: SwiftUI.Color
    }

    enum Colors {
        // MARK: Surfaces (linen ≈60%)
        static let canvas = Sourdough.dynamic(light: 0xFBF7F1, dark: 0x211E1B)
        static let card = Sourdough.dynamic(light: 0xFFFCF7, dark: 0x2B2724)
        /// Sunken surface for search fields / segmented tracks (linen100 in light; no exact dark
        /// value given in spec — derived via the same translucent-tint pattern used elsewhere for
        /// dark-mode fills, blended over whatever surface it sits on).
        static let sunken = Sourdough.dynamic(light: 0xF2EDE4, dark: 0x2B2724, darkAlpha: 0.6)
        /// Decorative separators only (1.1:1 — not for interactive borders).
        static let hairline = Sourdough.dynamic(
            light: 0xEBE3D8, dark: 0x3D3833,
            highContrastLight: 0xC4BCB2, highContrastDark: 0x6B6259
        )
        /// Interactive borders (2.0:1) — always pair with the 44pt hit target.
        static let interactiveBorder = Sourdough.dynamic(
            light: 0xC4BCB2, dark: 0x6B6259,
            highContrastLight: 0x6B6259
        )

        // MARK: Ink (≈30%)
        static let ink = Sourdough.dynamic(light: 0x2E2A26, dark: 0xF5F0E8)
        /// Secondary lines (4.9:1 AA) — prefer 13pt+ in practice even where 11pt technically clears AA.
        static let mutedInk = Sourdough.dynamic(
            light: 0x6B6259, dark: 0xA79E92,
            highContrastLight: 0x554E46
        )
        /// Inactive tab icons/labels ONLY (2.4:1, fails AA) — must pair with a shape change on the
        /// active state, never used for body text.
        static let faintInk = Sourdough.dynamic(light: 0xA79E92, dark: 0x6B6259)

        // MARK: Action (terracotta ≤2%)
        /// Filled buttons, active tab icon, FAB. Never use as a text color — see `actionInk`.
        static let action = Sourdough.dynamic(light: 0xC4643F, dark: 0xE08055)
        /// Press state fill AND all small colored text/links/text buttons (4.9:1 AA).
        static let actionInk = Sourdough.dynamic(light: 0xA44E2E, dark: 0xE08055)
        static let actionPressed = actionInk
        static let onAction = Ramp.onFilled

        // MARK: Destructive
        static let destructive = Sourdough.dynamic(light: 0x8E3A2A, dark: 0x8E3A2A)
        static let onDestructive = Ramp.onFilled

        // MARK: Freshness states (sage/honey ≈8% — 100-tints only; urgent is the sole solid-fill exception)
        static let fresh = FreshnessStyle(
            tint: Sourdough.dynamic(light: 0xE9EEE4, dark: 0x93A588, darkAlpha: 0.18),
            label: Sourdough.dynamic(light: 0x47543C, dark: 0x93A588)
        )
        static let soon = FreshnessStyle(
            tint: Sourdough.dynamic(light: 0xFAEBCD, dark: 0xEFCF95, darkAlpha: 0.18),
            label: Sourdough.dynamic(light: 0x6E5426, dark: 0xEFCF95)
        )
        /// Inverts structurally in dark mode (§6): light = solid terracotta500 fill; dark = tint
        /// fill `#4A2A1D` — both values are opaque, so `FreshnessChip` can render both the same way
        /// (`background(tint).foregroundStyle(label)`) with no extra branching.
        static let urgent = FreshnessStyle(
            tint: Sourdough.dynamic(light: 0xC4643F, dark: 0x4A2A1D),
            label: Sourdough.dynamic(light: 0xFFF6F1, dark: 0xFFB894)
        )
        static let expired = FreshnessStyle(
            tint: Sourdough.dynamic(light: 0xF2EDE4, dark: 0x3D3833),
            label: Sourdough.dynamic(light: 0x6B6259, dark: 0xA79E92)
        )

        // MARK: On-dark hero card (§5/§6)
        static let heroTitleOnDark = Ramp.darkTextPrimary
        static let heroMetaOnDark = Ramp.darkTextMuted
        /// The only accent proven to hold contrast on the dark hero card; `action` already resolves
        /// to the lifted `#E08055` in dark mode as a fallback, but honey-300 is preferred there.
        static let heroAccentOnDark = Ramp.honeyDark
        /// Reduce Transparency override: swap any 10%-opacity white chip fill on the dark hero card
        /// to this solid color instead.
        static let heroChipFillReducedTransparency = Ramp.darkChipFillOpaque
    }
}
