import SwiftUI

#Preview("Main Tabs") {
    PreviewContainer {
        MainTabView(recipeGenerator: previewRecipeGenerator)
    }
}

enum Tab: Int, CaseIterable {
    case pantry = 0
    case recipes = 1
    case profile = 2

    var title: String {
        switch self {
        case .pantry: return "Pantry"
        case .recipes: return "Recipes"
        case .profile: return "Profile"
        }
    }

    var iconPath: String {
        switch self {
        case .pantry: return TabIconPath.pantry
        case .recipes: return TabIconPath.recipe
        case .profile: return TabIconPath.profile
        }
    }
}

struct MainTabView: View {
    let recipeGenerator: RecipeGenerating
    @State private var selectedTab: Tab = .pantry
    @State private var slideDirection: Edge = .trailing
    @State private var showGenerate = false
    @State private var requestPantryAdd = false
    @State private var addMenuExpanded = false

    var body: some View {
        ZStack {
            // Content – keep all tabs alive to preserve scroll position & state
            ZStack {
                NavigationStack { PantryView(requestAddSheet: $requestPantryAdd) }
                    .opacity(selectedTab == .pantry ? 1 : 0)
                    .allowsHitTesting(selectedTab == .pantry)

                NavigationStack { RecipesView() }
                    .opacity(selectedTab == .recipes ? 1 : 0)
                    .allowsHitTesting(selectedTab == .recipes)

                NavigationStack { ProfileView() }
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }

            // Dismiss scrim when expanded
            if addMenuExpanded {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            addMenuExpanded = false
                        }
                    }
            }

            // Tab bar
            VStack {
                Spacer()
                FloatingTabBar(
                    selectedTab: $selectedTab,
                    slideDirection: $slideDirection,
                    expanded: $addMenuExpanded,
                    onAddToPantry: {
                        addMenuExpanded = false
                        selectedTab = .pantry
                        requestPantryAdd = true
                    },
                    onGenerate: {
                        addMenuExpanded = false
                        showGenerate = true
                    }
                )
            }
        }
        .sheet(isPresented: $showGenerate) {
            NavigationStack {
                GenerateView(recipeGenerator: recipeGenerator)
            }
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var slideDirection: Edge
    @Binding var expanded: Bool
    var onAddToPantry: () -> Void
    var onGenerate: () -> Void
    var body: some View {
        HStack(spacing: DS.Spacing.space3) {
            if expanded {
                expandedContent
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else {
                collapsedContent
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.bottom, DS.Spacing.space2)
    }

    // MARK: - Collapsed (normal tab bar)

    private var collapsedContent: some View {
        HStack(spacing: DS.Spacing.space3) {
            // Tab pill
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

            // Add button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expanded = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(DS.ColorToken.accent)
                            .shadow(color: DS.ColorToken.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
        }
    }

    // MARK: - Expanded (action options)

    private var expandedContent: some View {
        HStack(spacing: DS.Spacing.space3) {
            // Action pill
            HStack(spacing: 0) {
                AddMenuButton(icon: "refrigerator.fill", label: "Add to Pantry", action: onAddToPantry)
                AddMenuButton(icon: "wand.and.stars", label: "Generate Recipe", action: onGenerate)
            }
            .padding(.vertical, DS.Spacing.space2)
            .padding(.horizontal, DS.Spacing.space5)
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

            // Close button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expanded = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(DS.ColorToken.textSecondary)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
            }
        }
    }
}

// MARK: - Add Menu Button

private struct AddMenuButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(label)
                    .font(.custom("Satoshi Variable", size: 11))
            }
            .foregroundStyle(DS.ColorToken.textPrimary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                SVGIcon(tab.iconPath, size: 22)

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
