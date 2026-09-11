import SwiftUI

#Preview("Get Started") {
    PreviewContainer(authenticated: false) {
        NavigationStack {
            GetStartedView()
        }
    }
}

// MARK: - Local hex helper (file-scoped, mirrors SourdoughColors.swift's own private pattern —
// these three gradient stops are bespoke to this screen, not part of the named token palette)

private extension Color {
    init(welcomeHex hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct GetStartedView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showingOnboarding = false
    @State private var showingSignIn = false

    @State private var cardsAppeared = false
    @State private var headlineAppeared = false
    @State private var footerAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    cardStack(availableHeight: proxy.size.height)
                        .padding(.top, 26)

                    Spacer(minLength: 0)

                    headlineBlock
                        .padding(.horizontal, 26)

                    Spacer(minLength: 0)

                    footer
                }
                .frame(height: proxy.size.height)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { runEntranceAnimations() }
        .fullScreenCover(isPresented: $showingOnboarding) {
            PreSignupOnboardingContainerView()
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            SignInView()
                .environmentObject(session)
        }
    }

    private func runEntranceAnimations() {
        // Each card carries its own `.animation(_:value:)` modifier (with its own stagger
        // delay), so a single plain flip here is enough to trigger all three.
        cardsAppeared = true
        withAnimation(.easeOut(duration: 0.4).delay(reduceMotion ? 0 : 0.18)) {
            headlineAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(reduceMotion ? 0 : 0.35)) {
            footerAppeared = true
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let ellipseWidth = w * 1.2
            let ellipseHeight = h * 0.58

            Circle()
                .fill(gradientFill(radius: ellipseWidth / 2))
                .frame(width: ellipseWidth, height: ellipseWidth)
                .scaleEffect(x: 1, y: ellipseWidth > 0 ? ellipseHeight / ellipseWidth : 1)
                .position(x: w * 0.5, y: h * 0.08)
        }
        .ignoresSafeArea()
    }

    private func gradientFill(radius: CGFloat) -> RadialGradient {
        if colorScheme == .dark {
            return RadialGradient(
                gradient: Gradient(colors: [Sourdough.Ramp.darkCard, Sourdough.Ramp.darkCanvas]),
                center: .center, startRadius: 0, endRadius: radius
            )
        }
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(welcomeHex: 0xFDF4EF), location: 0),
                .init(color: Color(welcomeHex: 0xFBF7F1), location: 0.56),
                .init(color: Color(welcomeHex: 0xF5F0E7), location: 1),
            ]),
            center: .center, startRadius: 0, endRadius: radius
        )
    }

    // MARK: - Fanned card stack

    private struct PreviewCardSpec {
        let emoji: String
        let name: String
        let meta: String
        let tileColor: Color
        let badgeState: Sourdough.FreshnessState
        let badgeText: String
        let inset: CGFloat
        /// Fixed point offset from the top of the fan — deliberately *not* a fraction of the
        /// responsive container height. Scaling the stagger with screen size either crops labels
        /// on small screens or spreads the cards apart into separate tiles on large ones; a fixed,
        /// modest overlap reads as one fanned stack on every device.
        let offsetY: CGFloat
        let rotation: Double
    }

    private var previewCards: [PreviewCardSpec] {
        [
            PreviewCardSpec(
                emoji: "🧀", name: "Parmesan", meta: "180 g · Fridge",
                tileColor: Sourdough.Ramp.sage100, badgeState: .fresh, badgeText: "Fresh",
                inset: 26, offsetY: 75, rotation: -2
            ),
            PreviewCardSpec(
                emoji: "🥛", name: "Greek yogurt", meta: "500 g · Fridge",
                tileColor: Sourdough.Ramp.honey100, badgeState: .soon, badgeText: "3 days",
                inset: 22, offsetY: 140, rotation: 1
            ),
            PreviewCardSpec(
                emoji: "🥬", name: "Baby spinach", meta: "120 g · Fridge",
                tileColor: Sourdough.Ramp.terracotta100, badgeState: .urgent, badgeText: "Today",
                inset: 18, offsetY: 210, rotation: -2
            ),
        ]
    }

    private func cardStack(availableHeight: CGFloat) -> some View {
        let containerHeight = availableHeight * 0.5
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At the largest Dynamic Type sizes, one straight card keeps the headline and
                // CTA on screen rather than three overlapping, individually-rotated ones.
                previewCard(previewCards[2])
                    .padding(.horizontal, 18)
                    .frame(height: 96)
            } else {
                ZStack(alignment: .top) {
                    ForEach(Array(previewCards.enumerated()), id: \.offset) { index, spec in
                        let baseOffset = spec.offsetY
                        previewCard(spec)
                            .padding(.horizontal, spec.inset)
                            .padding(.top, cardsAppeared ? baseOffset : baseOffset + (reduceMotion ? 0 : 24))
                            .scaleEffect(cardsAppeared ? 1 : (reduceMotion ? 1 : 1.03))
                            .rotationEffect(.degrees(cardsAppeared ? spec.rotation : (reduceMotion ? spec.rotation : spec.rotation * 1.5)))
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(cardAnimation(delay: Double(index) * 0.07), value: cardsAppeared)
                    }
                }
                .frame(height: containerHeight, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Preview of your pantry: Parmesan, fresh. Greek yogurt, use in 3 days. Baby spinach, use today."
        )
    }

    private func previewCard(_ spec: PreviewCardSpec) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(spec.tileColor)
                .frame(width: 38, height: 38)
                .overlay(Text(spec.emoji).font(.system(size: 18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name)
                    .font(sourdoughFont(family: .figtree, size: 14, weight: 600, dynamicTypeStyle: .body))
                    .foregroundStyle(Sourdough.Colors.ink)
                Text(spec.meta)
                    .font(sourdoughFont(family: .figtree, size: 11.5, weight: 400, dynamicTypeStyle: .caption1))
                    .foregroundStyle(Sourdough.Colors.mutedInk)
            }

            Spacer(minLength: 8)

            FreshnessChip(state: spec.badgeState, dayCountText: spec.badgeText)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: 18)
    }

    private func cardAnimation(delay: Double) -> Animation {
        let base: Animation = reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.45, dampingFraction: 0.8)
        return base.delay(delay)
    }

    // MARK: - Headline block

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            headlineText
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headlineAppeared ? 1 : 0)
                .offset(y: headlineAppeared || reduceMotion ? 0 : 12)

            Text("Every item gets a date. Every date gets a recipe. Nothing gets binned.")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.body)
                .padding(.top, 13)
                .opacity(headlineAppeared ? 1 : 0)
                .offset(y: headlineAppeared || reduceMotion ? 0 : 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headlineText: some View {
        // `.sourdoughTextStyle(_:)` can't be applied mid-`+`-concatenation (it returns `some
        // View`, not `Text`), so this pulls `.hero`'s real attributes — size, weight, tracking,
        // line-height, Dynamic Type style — directly, the same way `TextStyleModifier` does
        // internally, rather than hand-picking a one-off size for this screen.
        let attrs = Sourdough.Typography.attributes(for: .hero)
        let italicFont = sourdoughFont(
            family: .newsreader, size: attrs.size, weight: attrs.weight,
            dynamicTypeStyle: attrs.dynamicTypeStyle, italic: true
        )

        return (
            Text("Use it up\nbefore it's ")
                .font(Sourdough.SDFont.font(for: .hero))
                .foregroundColor(Sourdough.Colors.ink)
            + Text("up.")
                .font(italicFont)
                .foregroundColor(Sourdough.Colors.actionInk)
        )
        .tracking(attrs.tracking * attrs.size)
        .lineSpacing(max(0, attrs.lineHeight - attrs.size))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 11) {
            Button {
                showingOnboarding = true
            } label: {
                Text("Start cooking")
                    .font(sourdoughFont(family: .figtree, size: 16, weight: 600, dynamicTypeStyle: .body))
                    .foregroundStyle(Sourdough.Ramp.onFilled)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Sourdough.Colors.action)
                    .clipShape(Capsule())
                    .shadow(color: Sourdough.Colors.actionInk.opacity(0.70), radius: 11, x: 0, y: 10)
            }
            .buttonStyle(.plain)

            Button {
                showingSignIn = true
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                    Text("Log in")
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .fontWeight(.semibold)
                }
                .font(sourdoughFont(family: .figtree, size: 13, weight: 400, dynamicTypeStyle: .footnote))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .opacity(footerAppeared ? 1 : 0)
        .offset(y: footerAppeared || reduceMotion ? 0 : 12)
    }
}

// MARK: - Custom-size font helper

/// Same Dynamic-Type-scaling/capping methodology as `Sourdough.SDFont.font(for:)` (Newsreader
/// capped ~1.6x, Figtree uncapped), generalized to arbitrary sizes this screen's spec calls for
/// that don't land on any of the 9 named `Sourdough.Typography.Style` cases.
private func sourdoughFont(
    family: Sourdough.FontFamily, size: CGFloat, weight: CGFloat, dynamicTypeStyle: UIFont.TextStyle, italic: Bool = false
) -> Font {
    let base = Sourdough.SDFont.uiFont(family: family, size: size, weight: weight, italic: italic)
    let cap = family == .newsreader ? size * 1.6 : CGFloat.greatestFiniteMagnitude
    let scaled = UIFontMetrics(forTextStyle: dynamicTypeStyle).scaledFont(for: base, maximumPointSize: cap)
    return Font(scaled as CTFont)
}
