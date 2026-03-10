# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an iOS 17+ SwiftUI app using XcodeGen for project generation.

```bash
# Regenerate Xcode project after adding/removing files
xcodegen generate

# Build from command line
xcodebuild -project UseUp.xcodeproj -scheme UseUp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# No test targets are configured
```

When adding new Swift files, you must add them to `UseUp.xcodeproj/project.pbxproj` manually (PBXBuildFile, PBXFileReference, PBXGroup children, and Sources build phase) unless regenerating via `xcodegen generate`.

## Architecture

### App Layer (`App/`)
- **UseUp.swift** — Entry point. Creates `AppSession` with `SupabaseAuthService` and injects environment objects.
- **AppSession.swift** — `@MainActor ObservableObject` that owns all auth/user state. Drives navigation via published properties (`isCheckingSession`, `isAuthenticated`, `hasSeenGetStarted`, `hasCompletedFeatureOnboarding`).
- **AppRootView.swift** — Routes based on `AppSession` state: Splash → GetStarted → FeatureOnboarding → MainTabView.

### Service Pattern
Protocol-driven with real and mock implementations:
- `AuthServicing` → `SupabaseAuthService` / `MockAuthService` — Phone OTP auth
- `ProfileServicing` → `SupabaseProfileService` / `MockProfileService` — Profile CRUD with 30-day nickname cooldown
- `RecipeGenerating` → `MockRecipeGenerator` — Recipe generation (no real AI integration yet)

Mock services are used in `PreviewContainer` for Xcode canvas previews. Real services use `SupabaseManager.client` singleton from `Core/Services/SupabaseClient.swift`.

### State Management
- **AppSession** — Auth state, user profile data. Passed via `.environmentObject()`.
- **PantryStore** — Ingredient CRUD with Supabase sync and optimistic updates (immediate UI update, rollback on error).
- **SavedRecipesStore** / **MacrosStore** — Domain stores, also environment objects.

### Design System (`Core/DesignSystem/DesignSystem.swift`)
Everything is namespaced under `DS`:
- `DS.Spacing.space0` through `space24` (4–96pt)
- `DS.Radius.sm`, `.md`, `.lg`, `.xl`, `.full`
- `DS.ColorToken.primary`, `.textPrimary`, `.bgPrimary`, `.error`, etc. (light/dark aware)
- `DS.Motion.fast`, `.normal`, `.slow` (animation curves)
- `.appTextStyle(.bodySM)` modifier for typography
- Fonts: `CalSans-Regular` (headings), `Satoshi Variable` (body text)

### Database
Supabase backend. Schema defined in `Migrations/001_initial_schema.sql`. Key tables:
- `profiles` — id, nickname, display_name, avatar_path, updated_at
- `ingredients` — user's pantry items with category, location, expiration
- `recipes`, `recipe_ingredients`, `recipe_ratings`, `saved_recipes`

RLS policies enforce `auth.uid() = id` (profiles) or `auth.uid() = user_id` (other tables). A `handle_new_user()` trigger auto-creates a profile row on signup.

### Feature Modules (`Features/`)
Each feature is a directory with its views:
- **Auth** — Phone OTP flow: AuthView → OTPVerificationView → NicknameOnboardingView
- **Onboarding** — SplashView, GetStartedView, FeatureOnboardingView
- **Pantry** — Ingredient management with filtering, search, expiration tracking
- **Recipes** — Browse saved/shared recipes
- **Generate** — AI recipe generation from pantry ingredients
- **Profile** — User profile editing, settings
- **Macros** — Macro tracking (partially implemented)

## Key Conventions

- Supabase column names use `snake_case`; Swift models use `CodingKeys` to map to `camelCase`
- `PreviewContainer(authenticated:)` wraps views with mock environment objects for previews
- Button styles: `PrimaryButtonStyle(size:fullWidth:)`, `AuthBackButtonStyle`
- Input fields: `AppInputFieldStyle(size:)`
- Auth helpers (`FastTapScrollModifier`, `SwipeBackEnabler`) live in `AuthView.swift`

## Dependencies

- **Supabase Swift SDK** (v2.5.1+) — Auth, database, storage
