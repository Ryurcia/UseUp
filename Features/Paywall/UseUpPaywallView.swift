import SwiftUI
import RevenueCat
import PhosphorSwift

struct UseUpPaywallView: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject private var rcManager = RevenueCatManager.shared

    let onDismiss: () -> Void

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    /// RevenueCat's `ErrorCode.purchaseCancelledError.rawValue` — thrown when the user dismisses
    /// the App Store purchase sheet themselves, which shouldn't surface as an error message.
    private let purchaseCancelledErrorCode = 2

    private var monthlyPackage: Package? {
        rcManager.currentOffering?.availablePackages.first { $0.packageType == .monthly }
    }

    private var annualPackage: Package? {
        rcManager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        headerImage
                        contentSection
                        offerSection(bottomInset: proxy.safeAreaInsets.bottom)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: proxy.size.height)
                }
                .background(
                    LinearGradient(
                        colors: [DS.ColorToken.bgPrimary, DS.ColorToken.primary.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .ignoresSafeArea()

            closeButton
        }
        .task {
            if rcManager.currentOffering == nil {
                await rcManager.fetchOfferings()
            }
            if selectedPackage == nil {
                selectedPackage = annualPackage ?? monthlyPackage
            }
        }
    }

    // MARK: - Header image

    private var headerImage: some View {
        Image("PAYWALL_IMAGE")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(DS.ColorToken.bgPrimary)
    }

    // MARK: - Features content

    private var contentSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.space3) {
            HStack(spacing: 0) {
                Text("Unlock UseUp ")
                    .font(.custom("CalSans-Regular", size: 40))
                    .foregroundColor(DS.ColorToken.textPrimary)
                Text("Pro")
                    .font(.custom("CalSans-Regular", size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.75, blue: 0.2), DS.ColorToken.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("WHAT YOU GET WITH PRO")
                .appTextStyle(.overline)
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            featureCard
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space4)
        .padding(.bottom, DS.Spacing.space4)
        .background(DS.ColorToken.bgPrimary)
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ProFeature.all.indices, id: \.self) { index in
                ProFeatureRow(feature: ProFeature.all[index])
                if index < ProFeature.all.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.space3)
        .padding(.vertical, DS.Spacing.space2)
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    // MARK: - Offer section

    private func offerSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: DS.Spacing.space3) {
            HStack(spacing: DS.Spacing.space3) {
                if rcManager.currentOffering == nil {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(Color.white.opacity(0.7))
                        .frame(height: 90)
                        .redacted(reason: .placeholder)
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(Color.white.opacity(0.7))
                        .frame(height: 90)
                        .redacted(reason: .placeholder)
                } else {
                    if let monthly = monthlyPackage {
                        OfferCard(
                            package: monthly,
                            label: "Monthly",
                            isSelected: selectedPackage?.identifier == monthly.identifier
                        ) { selectedPackage = monthly }
                    }
                    if let annual = annualPackage {
                        OfferCard(
                            package: annual,
                            label: "Yearly",
                            isSelected: selectedPackage?.identifier == annual.identifier
                        ) { selectedPackage = annual }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.space5)

            if let errorMessage {
                Text(errorMessage)
                    .appTextStyle(.caption)
                    .foregroundColor(DS.ColorToken.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.space5)
            }

            Button {
                guard let pkg = selectedPackage else { return }
                Task { await purchase(pkg) }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .font(.custom("Satoshi Variable", size: 16))
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(DS.ColorToken.primary)
                .clipShape(Capsule())
            }
            .disabled(isPurchasing || isRestoring || selectedPackage == nil)
            .padding(.horizontal, DS.Spacing.space5)

            Button {
                Task { await restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.custom("Satoshi Variable", size: 14))
                    .fontWeight(.bold)
                    .underline()
                    .foregroundColor(DS.ColorToken.textPrimary)
            }
            .disabled(isPurchasing || isRestoring)


            Text("By subscribing, you agree to our [Terms & Conditions](\(AuthLegalLinks.terms)) and [Privacy Policy](\(AuthLegalLinks.privacy)).")
                .appTextStyle(.caption)
                .foregroundColor(DS.ColorToken.textSecondary)
                .tint(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.space5)

            Spacer(minLength: DS.Spacing.space5)
        }
        .padding(.top, DS.Spacing.space4)
        .padding(.bottom, bottomInset)
        .background(
            LinearGradient(
                colors: [DS.ColorToken.bgPrimary, DS.ColorToken.primary.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button(action: onDismiss) {
            Ph.x.regular
                .frame(width: 14, height: 14)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.trailing, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space3)
    }

    // MARK: - Actions

    private func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            _ = try await rcManager.purchase(package: package)
            session.isPremium = true
            onDismiss()
        } catch {
            if error is CancellationError { return }
            let nsError = error as NSError
            guard nsError.code != purchaseCancelledErrorCode else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            let info = try await rcManager.restorePurchases()
            if !info.entitlements.active.isEmpty {
                session.isPremium = true
                onDismiss()
            } else {
                errorMessage = "No active subscriptions found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ProFeature

private struct ProFeature {
    let emoji: String
    let title: String
    let description: String

    static let all: [ProFeature] = [
        .init(emoji: "✨", title: "Generate Up to 25 Recipes Per Day",
              description: "Pro users can generate up to 5 times per day, with each generation providing 5 recipes."),
        .init(emoji: "🍽️", title: "Advanced Recipe Filters",
              description: "Pro users can customize cook time, cuisine, calorie target and more."),
.init(emoji: "🗣️", title: "Speech Recognition",
              description: "On iOS 26 and later, say your ingredients out loud to log them instantly instead of typing."),
        .init(emoji: "📷", title: "Barcode Scanning",
              description: "Scan any food item's barcode to instantly auto-fill the name, quantity, and category when adding ingredients."),
        .init(emoji: "🔓", title: "Access to Future Pro Features",
              description: "Automatic access to all features that will be added later on."),
       
    ]
}

// MARK: - ProFeatureRow

private struct ProFeatureRow: View {
    let feature: ProFeature

    var body: some View {
        HStack(spacing: DS.Spacing.space3) {
            Text(feature.emoji)
                .font(.system(size: 18))
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                Text(feature.title)
                    .appTextStyle(.bodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(DS.ColorToken.textPrimary)
                Text(feature.description)
                    .appTextStyle(.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.space2)
    }
}

// MARK: - OfferCard

private struct OfferCard: View {
    let package: Package
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void

    private var perMonthString: String? {
        guard package.packageType == .annual,
              let formatter = package.storeProduct.priceFormatter else { return nil }
        let perMonth = package.storeProduct.price / Decimal(12)
        return formatter.string(from: NSDecimalNumber(decimal: perMonth)).map { "\($0)/mo" }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DS.Spacing.space1) {
                Text(label)
                    .appTextStyle(.bodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? DS.ColorToken.primary : DS.ColorToken.textSecondary)

                Text(package.storeProduct.localizedPriceString)
                    .appTextStyle(.heading3)
                    .foregroundColor(isSelected ? DS.ColorToken.primary : DS.ColorToken.textPrimary)

                Text(perMonthString ?? "per month")
                    .appTextStyle(.caption)
                    .foregroundColor(DS.ColorToken.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.space4)
            .background(isSelected ? DS.ColorToken.primary.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(
                        isSelected ? DS.ColorToken.primary : DS.ColorToken.borderDefault,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

#Preview {
    UseUpPaywallView { }
        .environmentObject(AppSession(authService: MockAuthService()))
}
