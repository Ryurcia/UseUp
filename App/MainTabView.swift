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
    case pantry = 0
    case recipes = 1
    case generate = 2
    case cookbook = 3

    var title: String {
        switch self {
        case .pantry: return "Pantry"
        case .recipes: return "Recipes"
        case .generate: return "Generate"
        case .cookbook: return "Cookbook"
        }
    }

    var phosphorIcon: Image {
        switch self {
        case .pantry: return Ph.jarLabel.bold
        case .recipes: return Ph.notebook.bold
        case .generate: return Ph.chefHat.bold
        case .cookbook: return Ph.bookOpenText.bold
        }
    }
}

struct MainTabView: View {
    let recipeGenerator: RecipeGenerating
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: Tab = .pantry
    @State private var slideDirection: Edge = .trailing
    @State private var pantryPath = NavigationPath()
    @State private var recipesPath = NavigationPath()
    @State private var generatePath = NavigationPath()
    @State private var cookbookPath = NavigationPath()
    @State private var hideTabBar = false

    private func notificationBinding(for tab: Tab) -> Binding<Bool> {
        Binding(
            get: { session.showNotifications && selectedTab == tab },
            set: { if !$0 { session.showNotifications = false } }
        )
    }

    var body: some View {
        ZStack {
            ZStack {
                NavigationStack(path: $pantryPath) {
                    PantryView()
                        .navigationDestination(isPresented: notificationBinding(for: .pantry)) {
                            NotificationListView()
                        }
                }
                .opacity(selectedTab == .pantry ? 1 : 0)
                .allowsHitTesting(selectedTab == .pantry)

                NavigationStack(path: $recipesPath) {
                    RecipesView()
                        .navigationDestination(isPresented: notificationBinding(for: .recipes)) {
                            NotificationListView()
                        }
                }
                .opacity(selectedTab == .recipes ? 1 : 0)
                .allowsHitTesting(selectedTab == .recipes)

                NavigationStack(path: $generatePath) {
                    GenerateView(recipeGenerator: recipeGenerator)
                        .navigationDestination(isPresented: notificationBinding(for: .generate)) {
                            NotificationListView()
                        }
                }
                .opacity(selectedTab == .generate ? 1 : 0)
                .allowsHitTesting(selectedTab == .generate)

                NavigationStack(path: $cookbookPath) {
                    CookbookView()
                        .navigationDestination(isPresented: notificationBinding(for: .cookbook)) {
                            NotificationListView()
                        }
                }
                .opacity(selectedTab == .cookbook ? 1 : 0)
                .allowsHitTesting(selectedTab == .cookbook)
            }
            .onChange(of: selectedTab) { _, _ in
                pantryPath = NavigationPath()
                recipesPath = NavigationPath()
                generatePath = NavigationPath()
                cookbookPath = NavigationPath()
                session.showNotifications = false
            }
            .onChange(of: session.requestedTab) { _, tab in
                guard let tab else { return }
                session.showNotifications = false
                selectedTab = tab
                session.requestedTab = nil
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
                    FloatingTabBar(
                        selectedTab: $selectedTab,
                        slideDirection: $slideDirection
                    )
                }
            }
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var slideDirection: Edge

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    slideDirection = tab.rawValue > selectedTab.rawValue ? .trailing : .leading
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.space2)
        .padding(.horizontal, DS.Spacing.space5)
        .modifier(TabBarBackgroundModifier())
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.bottom, DS.Spacing.space2)
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
                        .stroke(DS.ColorToken.borderDefault.opacity(0.3), lineWidth: 0.5)
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
                    ? DS.ColorToken.accent
                    : DS.ColorToken.textTertiary
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
