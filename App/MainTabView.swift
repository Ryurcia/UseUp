import SwiftUI
import PhosphorSwift

struct HideTabBarKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

#Preview("Main Tabs") {
    PreviewContainer {
        MainTabView(recipeGenerator: previewRecipeGenerator)
    }
}

enum Tab: Int, CaseIterable {
    case home = 0
    case pantry = 1
    case recipes = 2
    case generate = 3

    var title: String {
        switch self {
        case .home: return "Home"
        case .pantry: return "Pantry"
        case .recipes: return "Recipes"
        case .generate: return "Generate"
        }
    }

    var phosphorIcon: Image {
        switch self {
        case .home: return Ph.house.bold
        case .pantry: return Ph.basket.bold
        case .recipes: return Ph.notebook.bold
        case .generate: return Ph.chefHat.bold
        }
    }
}

struct MainTabView: View {
    let recipeGenerator: RecipeGenerating
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var pantryPath = NavigationPath()
    @State private var recipesPath = NavigationPath()
    @State private var generatePath = NavigationPath()
    @State private var hideTabBar = false

    // Global "Add Ingredient" flow — lives here (not PantryView) so it's reachable from any tab.
    // Pro is required to log items at all: Photo Scan is the sole logging entry point, gated by
    // the paywall for free accounts (manual entry has been fully retired).
    @State private var showingPhotoScan = false
    @State private var showingPaywall = false

    private func notificationBinding(for tab: Tab) -> Binding<Bool> {
        Binding(
            get: { session.showNotifications && selectedTab == tab },
            set: { if !$0 { session.showNotifications = false } }
        )
    }

    private func profileBinding(for tab: Tab) -> Binding<Bool> {
        Binding(
            get: { session.showProfile && selectedTab == tab },
            set: { if !$0 { session.showProfile = false } }
        )
    }

    /// Single entry point for switching tabs. Generate requires Pro — a non-paying user tapping it
    /// gets the paywall and stays where they are (mirrors the "+" Add button's gate).
    private func selectTab(_ tab: Tab) {
        if tab == .generate, !session.isPremium {
            showingPaywall = true
            return
        }
        guard tab != selectedTab else {
            if tab == .home {
                homePath = NavigationPath()
                session.requestedPantryHomeReset.toggle()
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTab = tab
        }
    }

    var body: some View {
        ZStack {
            ZStack {
                NavigationStack(path: $homePath) {
                    HomeView(isActiveTab: selectedTab == .home)
                        .navigationDestination(isPresented: notificationBinding(for: .home)) {
                            NotificationListView()
                        }
                        .navigationDestination(isPresented: profileBinding(for: .home)) {
                            AccountSettingsView()
                        }
                }
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)

                NavigationStack(path: $pantryPath) {
                    PantryView()
                        .navigationDestination(isPresented: notificationBinding(for: .pantry)) {
                            NotificationListView()
                        }
                        .navigationDestination(isPresented: profileBinding(for: .pantry)) {
                            AccountSettingsView()
                        }
                }
                .opacity(selectedTab == .pantry ? 1 : 0)
                .allowsHitTesting(selectedTab == .pantry)

                NavigationStack(path: $recipesPath) {
                    RecipesView()
                        .navigationDestination(isPresented: notificationBinding(for: .recipes)) {
                            NotificationListView()
                        }
                        .navigationDestination(isPresented: profileBinding(for: .recipes)) {
                            AccountSettingsView()
                        }
                }
                .opacity(selectedTab == .recipes ? 1 : 0)
                .allowsHitTesting(selectedTab == .recipes)

                NavigationStack(path: $generatePath) {
                    GenerateView(recipeGenerator: recipeGenerator)
                        .navigationDestination(isPresented: notificationBinding(for: .generate)) {
                            NotificationListView()
                        }
                        .navigationDestination(isPresented: profileBinding(for: .generate)) {
                            AccountSettingsView()
                        }
                }
                .opacity(selectedTab == .generate ? 1 : 0)
                .allowsHitTesting(selectedTab == .generate)
            }
            .onChange(of: selectedTab) { _, _ in
                homePath = NavigationPath()
                pantryPath = NavigationPath()
                recipesPath = NavigationPath()
                generatePath = NavigationPath()
                session.showNotifications = false
                session.showProfile = false
            }
            .onChange(of: session.requestedTab) { _, tab in
                guard let tab else { return }
                session.showNotifications = false
                session.requestedTab = nil
                selectTab(tab)
            }
            .onChange(of: session.requestedShowAddIngredient) { _, requested in
                guard requested else { return }
                if session.isPremium {
                    showingPhotoScan = true
                } else {
                    showingPaywall = true
                }
                session.requestedShowAddIngredient = false
            }
            .onPreferenceChange(HideTabBarKey.self) { hideTabBar = $0 }
            .safeAreaInset(edge: .bottom) {
                if !hideTabBar {
                    Color.clear.frame(height: 80)
                }
            }

            if !hideTabBar {
                VStack {
                    Spacer()
                    GlobalBottomNav(
                        selectedTab: selectedTab,
                        onSelect: selectTab,
                        onAddTapped: {
                            if session.isPremium {
                                showingPhotoScan = true
                            } else {
                                showingPaywall = true
                            }
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showingPhotoScan) {
            PhotoScanCaptureView(onComplete: { showingPhotoScan = false })
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            UseUpPaywallView(onDismiss: { showingPaywall = false })
        }
    }
}

// MARK: - Global Bottom Nav (two groups: tabs pill + isolated Add circle)

private struct GlobalBottomNav: View {
    let selectedTab: Tab
    let onSelect: (Tab) -> Void
    let onAddTapped: () -> Void

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            TabGroup(selectedTab: selectedTab, onSelect: onSelect)
            AddPillButton(action: onAddTapped)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.insideChip)
    }
}

// MARK: - Group A: tab cluster

private struct TabGroup: View {
    let selectedTab: Tab
    let onSelect: (Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    onSelect(tab)
                }
            }
        }
        .padding(.vertical, Sourdough.Spacing.insideChip)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .modifier(TabBarBackgroundModifier())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tab Bar Background Modifier

private struct TabBarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(in: .capsule)
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    Capsule()
                        .stroke(Sourdough.Colors.hairline, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                tab.phosphorIcon
                    .frame(width: 26, height: 26)

                Text(tab.title)
                    .font(.custom("Satoshi Variable", size: 11).weight(isSelected ? .bold : .regular))
            }
            .foregroundStyle(
                isSelected
                    ? Sourdough.Colors.action
                    : Sourdough.Colors.mutedInk
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group B: isolated Add circle

/// Styling copied directly from the FAB this replaces (formerly `PantryView.fabButton`'s "+"
/// circle) — same size/fill/shadow, just relocated into the global nav. Opens Photo Scan for Pro
/// accounts, the paywall otherwise — logging an item requires Pro.
private struct AddPillButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Ph.plus.bold
                .frame(width: 24, height: 24)
                .foregroundStyle(Sourdough.Colors.onAction)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Sourdough.Colors.action)
                        .shadow(color: Sourdough.Ramp.linen900.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Ingredient")
    }
}
