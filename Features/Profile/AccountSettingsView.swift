import SwiftUI
import PhotosUI
import PhosphorSwift

#Preview("Account Settings") {
    PreviewContainer {
        NavigationStack {
            AccountSettingsView()
        }
    }
}

/// Sub-screens pushed from the profile screen onto the enclosing per-tab `NavigationStack`.
enum ProfilePush: Hashable { case settings, username, displayName, changePassword, changeEmail, help }

// MARK: - Profile screen

/// The user's profile — a scannable list where every setting shows its current value and tapping a
/// row opens a focused edit sheet. Pushed (not presented) via `session.showProfile`; see
/// `MainTabView`'s `profileBinding(for:)`.
struct AccountSettingsView: View {
    @EnvironmentObject private var session: AppSession

    // Editing state (seeded from `session` in `onAppear`; persisted by `save()`)
    @State private var selectedDietType: GenerationOptions.DietType = .any
    @State private var selectedRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    @State private var selectedAllergies: Set<AllergyType> = []
    @State private var selectedCustomAllergy: String = ""
    @State private var showAllergyOtherField = false
    @State private var selectedSkillLevel: Int = 1
    @State private var showPhotosPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var saveError: String?

    // Account state
    @State private var showPaywall = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    @State private var editingField: ProfileField?
    @State private var pushedScreen: ProfilePush?

    static let skillOptions: [(level: Int, label: String)] = [
        (1, "I'd rather order in"),
        (2, "I can cook a decent meal"),
        (3, "Just call me Gordon Ramsay"),
    ]

    static func skillLabel(_ level: Int) -> String {
        skillOptions.first { $0.level == level }?.label ?? skillOptions[0].label
    }

    // MARK: Derived

    private var cooldownMessage: String? {
        guard let remaining = cooldownRemainingDays(since: session.nicknameUpdatedAt, cooldownDays: 30) else { return nil }
        return "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var changeFlags: [Bool] {
        [
            selectedImage != nil,
            selectedDietType != session.currentUserDietaryPreference,
            selectedRestrictions != session.currentUserDietaryRestrictions,
            selectedAllergies != session.currentUserAllergies || selectedCustomAllergy != session.currentUserCustomAllergy,
            selectedSkillLevel != session.currentUserCookingSkillLevel,
        ]
    }

    private var hasChanges: Bool { changeFlags.contains(true) }
    private var dirtyCount: Int { changeFlags.filter { $0 }.count }

    private var displayTitle: String {
        let dn = (session.currentUserDisplayName ?? "").trimmingCharacters(in: .whitespaces)
        if !dn.isEmpty { return dn }
        let nn = (session.currentUserNickname ?? "").trimmingCharacters(in: .whitespaces)
        return nn.isEmpty ? "Chef" : nn
    }

    private var identitySubline: String {
        let handle = (session.currentUserNickname ?? "").trimmingCharacters(in: .whitespaces)
        let plan = session.isPremium ? "Pro" : "Free plan"
        return handle.isEmpty ? plan : "@\(handle) · \(plan)"
    }

    private var restrictionSummary: (text: String, muted: Bool) {
        summarize(Array(selectedRestrictions).map(\.rawValue).sorted())
    }

    private var allergySummary: (text: String, muted: Bool) {
        let all = selectedAllergies.map(\.rawValue).sorted()
            + AllergyType.parseCustomAllergens(selectedCustomAllergy)
        return summarize(all)
    }

    private func summarize(_ items: [String]) -> (text: String, muted: Bool) {
        if items.isEmpty { return ("None set", true) }
        if items.count == 1 { return (items[0], false) }
        return ("\(items[0]) +\(items.count - 1)", false)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                    if !session.isEmailVerified {
                        EmailVerificationBanner()
                    }
                    StatsSection()
                    cookingGroup
                    accountGroup
                    settingsRow
                    moreGroup
                    footerLinks
                    dangerZone
                    versionSection
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.betweenBlocks)
                .padding(.bottom, Sourdough.Spacing.underTitle)
            }

            saveBar
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: HideTabBarKey.self, value: true)
        .background(SwipeBackEnabler())
        .onAppear {
            selectedDietType = session.currentUserDietaryPreference
            selectedRestrictions = session.currentUserDietaryRestrictions
            selectedAllergies = session.currentUserAllergies
            selectedCustomAllergy = session.currentUserCustomAllergy
            showAllergyOtherField = !session.currentUserCustomAllergy.isEmpty
            selectedSkillLevel = session.currentUserCookingSkillLevel
            session.nicknameError = nil
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .navigationDestination(item: $pushedScreen) { screen in
            switch screen {
            case .settings:       SettingsView()
            case .username:       ProfileTextEditScreen(field: .username)
            case .displayName:    ProfileTextEditScreen(field: .displayName)
            case .changePassword: ChangePasswordView()
            case .changeEmail:    ChangeEmailView()
            case .help:           GetHelpView()
            }
        }
        .sheet(item: $editingField) { field in
            ProfileEditSheet(
                field: field,
                selectedDietType: $selectedDietType,
                selectedRestrictions: $selectedRestrictions,
                selectedAllergies: $selectedAllergies,
                selectedCustomAllergy: $selectedCustomAllergy,
                showAllergyOtherField: $showAllergyOtherField,
                selectedSkillLevel: $selectedSkillLevel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .alert("Error", isPresented: Binding(
            get: { saveError != nil || session.profileUpdateError != nil },
            set: { if !$0 { saveError = nil; session.profileUpdateError = nil } }
        )) {
            Button("OK") { saveError = nil; session.profileUpdateError = nil }
        } message: {
            Text(saveError ?? session.profileUpdateError ?? "")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await session.deleteAccount()
                    } catch {
                        isDeletingAccount = false
                        deleteError = "Failed to delete account: \(error.localizedDescription)"
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, pantry, recipes, and all data. This cannot be undone.")
        }
        .alert("Deletion Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack {
                Button { session.showProfile = false } label: {
                    Ph.caretLeft.regular
                        .frame(width: 17, height: 17)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            HStack(spacing: Sourdough.Spacing.rowInternals) {
                avatarButton

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .sourdoughTextStyle(.title2)
                        .lineLimit(1)
                    Text(identitySubline)
                        .sourdoughTextStyle(.subhead)
                        .lineLimit(1)
                }

                Spacer()

                colorSchemeToggle

                if !session.isPremium {
                    Button { showPaywall = true } label: {
                        Text("Go Pro")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.onAction)
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .frame(height: 30)
                            .background(Sourdough.Colors.action)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fullScreenCover(isPresented: $showPaywall) {
                        UseUpPaywallView { showPaywall = false }
                    }
                }
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Sourdough.Colors.hairline).frame(height: 1)
        }
    }

    private var colorSchemeToggle: some View {
        HStack(spacing: 2) {
            colorSchemeIcon(Ph.sun.fill, isActive: session.colorSchemePreference == .light) {
                session.colorSchemePreference = .light
            }
            colorSchemeIcon(Ph.moon.fill, isActive: session.colorSchemePreference == .dark) {
                session.colorSchemePreference = .dark
            }
        }
        .padding(3)
        .background(Sourdough.Colors.sunken)
        .clipShape(Capsule())
    }

    private func colorSchemeIcon(_ icon: Image, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 14, height: 14)
                .foregroundStyle(isActive ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                .frame(width: 26, height: 24)
                .background(isActive ? Sourdough.Ramp.sage500 : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var avatarButton: some View {
        Button { showPhotosPicker = true } label: {
            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage).resizable().scaledToFill()
                } else if let data = session.profileImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Text(String(displayTitle.first ?? "C").uppercased())
                        .sourdoughTextStyle(.title2, color: Sourdough.Ramp.sage600)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Sourdough.Ramp.sage100)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                Ph.pencil.bold
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .frame(width: 20, height: 20)
                    .background(Sourdough.Colors.action)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Sourdough.Colors.card, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Groups

    private var cookingGroup: some View {
        profileGroup(
            "Cooking for you",
            footer: "Applied to every recipe we generate. Allergies always win over preferences."
        ) {
            settingRow(icon: Ph.forkKnife.regular, tint: Sourdough.Ramp.sage100, ink: Sourdough.Ramp.sage600,
                       label: "Diet", value: selectedDietType.rawValue, valueMuted: false, first: true) {
                editingField = .diet
            }
            settingRow(icon: Ph.prohibit.regular, tint: Sourdough.Ramp.terracotta100, ink: Sourdough.Ramp.terracotta600,
                       label: "Restrictions", value: restrictionSummary.text, valueMuted: restrictionSummary.muted, first: false) {
                editingField = .restrictions
            }
            settingRow(icon: Ph.warning.regular, tint: Sourdough.Ramp.terracotta100, ink: Sourdough.Colors.destructive,
                       label: "Allergies", value: allergySummary.text, valueMuted: allergySummary.muted, first: false) {
                editingField = .allergies
            }
            settingRow(icon: Ph.chefHat.regular, tint: Sourdough.Ramp.honey100, ink: Sourdough.Ramp.honey700,
                       label: "Skill level", value: Self.skillLabel(selectedSkillLevel), valueMuted: false, first: false) {
                editingField = .skill
            }
        }
    }

    private var accountGroup: some View {
        profileGroup(
            "Account",
            footer: cooldownMessage ?? "Your handle and display name."
        ) {
            settingRow(icon: Ph.tag.regular, tint: Sourdough.Ramp.terracotta100, ink: Sourdough.Ramp.terracotta600,
                       label: "Username",
                       value: session.currentUserNickname.flatMap { $0.isEmpty ? nil : $0 } ?? "Not set",
                       valueMuted: session.currentUserNickname.flatMap { $0.isEmpty ? nil : $0 } == nil, first: true) {
                pushedScreen = .username
            }
            settingRow(icon: Ph.userCircle.regular, tint: Sourdough.Ramp.honey100, ink: Sourdough.Ramp.honey700,
                       label: "Display name",
                       value: session.currentUserDisplayName.flatMap { $0.isEmpty ? nil : $0 } ?? "Not set",
                       valueMuted: session.currentUserDisplayName.flatMap { $0.isEmpty ? nil : $0 } == nil, first: false) {
                pushedScreen = .displayName
            }
            settingRow(icon: Ph.envelope.regular, tint: Sourdough.Ramp.linen100, ink: Sourdough.Ramp.linen500,
                       label: "Email", value: session.currentUserEmail ?? "No email",
                       valueMuted: session.currentUserEmail == nil, first: false) {
                pushedScreen = .changeEmail
            }
            settingRow(icon: Ph.lock.regular, tint: Sourdough.Ramp.sage100, ink: Sourdough.Ramp.sage600,
                       label: "Change Password", value: "", valueMuted: false, first: false) {
                pushedScreen = .changePassword
            }
        }
    }

    private var settingsRow: some View {
        settingRow(icon: Ph.gear.regular, tint: Sourdough.Ramp.linen100, ink: Sourdough.Ramp.linen500,
                   label: "Settings", value: "", valueMuted: false, first: true) {
            pushedScreen = .settings
        }
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
    }

    private var moreGroup: some View {
        profileGroup("More", footer: "Questions, bugs, or ideas? We're here.") {
            settingRow(icon: Ph.question.regular, tint: Sourdough.Ramp.linen100, ink: Sourdough.Ramp.linen500,
                       label: "Get Help", value: "", valueMuted: false, first: true) {
                pushedScreen = .help
            }
            settingRow(icon: Ph.eyeSlash.regular, tint: Sourdough.Ramp.honey100, ink: Sourdough.Ramp.honey700,
                       label: "Privacy Policy", value: "", valueMuted: false, first: false) {
                UIApplication.shared.open(URL(string: "https://www.useupnow.com/privacy")!)
            }
            settingRow(icon: Ph.note.regular, tint: Sourdough.Ramp.sage100, ink: Sourdough.Ramp.sage600,
                       label: "Terms & Conditions", value: "", valueMuted: false, first: false) {
                UIApplication.shared.open(URL(string: "https://www.useupnow.com/terms")!)
            }
        }
    }

    @ViewBuilder
    private func profileGroup<Rows: View>(
        _ title: String,
        footer: String,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text(title)
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.faintInk)
                .padding(.leading, 4)

            VStack(spacing: 0) { rows() }
                .background(Sourdough.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)

            Text(footer)
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private func settingRow(
        icon: Image,
        tint: Color,
        ink: Color,
        label: String,
        value: String,
        valueMuted: Bool,
        first: Bool,
        tappable: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                icon
                    .frame(width: 13, height: 13)
                    .foregroundStyle(ink)
                    .frame(width: 26, height: 26)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

                Text(label)
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)

                Spacer(minLength: Sourdough.Spacing.rowInternals)

                Text(value)
                    .sourdoughTextStyle(.subhead, color: valueMuted ? Sourdough.Colors.faintInk : Sourdough.Colors.mutedInk)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if tappable {
                    Ph.caretRight.regular
                        .frame(width: 9, height: 12)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if !first {
                    Rectangle()
                        .fill(Sourdough.Colors.hairline)
                        .frame(height: 1)
                        .padding(.leading, 26 + Sourdough.Spacing.rowInternals * 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    // MARK: Footer + Danger Zone

    private var versionSection: some View {
        Text("1.0.0")
            .sourdoughTextStyle(.subhead, color: Sourdough.Colors.faintInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Button { session.signOut() } label: {
                Text("Sign Out")
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.destructive)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Danger Zone")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.faintInk)
                .padding(.leading, 4)

            Button { showDeleteAccountAlert = true } label: {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.trash.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Sourdough.Colors.destructive)
                    Text(isDeletingAccount ? "Deleting…" : "Delete Account")
                        .sourdoughTextStyle(.body, color: Sourdough.Colors.destructive)
                    Spacer()
                }
                .padding(Sourdough.Spacing.screenMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Sourdough.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
        }
    }

    // MARK: Save bar

    private var saveBar: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text(dirtyCount == 0
                 ? "Everything up to date."
                 : "\(dirtyCount) change\(dirtyCount == 1 ? "" : "s") not saved yet.")
                .sourdoughTextStyle(.caption, color: dirtyCount == 0 ? Sourdough.Colors.faintInk : Sourdough.Ramp.honey600)
                .lineLimit(1)

            Spacer(minLength: Sourdough.Spacing.insideChip)

            Button { save() } label: {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    if isSaving { ProgressView().tint(Sourdough.Colors.onAction) }
                    Text(hasChanges ? "Save" : "Saved")
                        .sourdoughTextStyle(.rowTitle, color: hasChanges ? Sourdough.Colors.onAction : Sourdough.Colors.faintInk)
                }
                .padding(.horizontal, Sourdough.Spacing.betweenBlocks)
                .frame(height: 40)
                .background(hasChanges ? Sourdough.Colors.action : Sourdough.Colors.sunken)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !hasChanges)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.rowInternals)
        .padding(.bottom, Sourdough.Spacing.insideChip)
        .background(Sourdough.Colors.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Sourdough.Colors.hairline).frame(height: 1)
        }
    }

    // MARK: Save

    private func save() {
        guard hasChanges else { return }

        _ = selectedImage != nil
        let hasDietChange = selectedDietType != session.currentUserDietaryPreference
        let hasRestrictionsChange = selectedRestrictions != session.currentUserDietaryRestrictions
        let hasAllergiesChange = selectedAllergies != session.currentUserAllergies || selectedCustomAllergy != session.currentUserCustomAllergy
        let hasSkillLevelChange = selectedSkillLevel != session.currentUserCookingSkillLevel

        Task {
            isSaving = true

            if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.8) {
                do {
                    try await session.updateProfilePhoto(data)
                    selectedImage = nil
                } catch {
                    saveError = "Failed to save photo. Please try again."
                }
            }
            if hasDietChange { await session.updateDietaryPreference(dietType: selectedDietType) }
            if hasRestrictionsChange { await session.updateDietaryRestrictions(restrictions: selectedRestrictions) }
            if hasAllergiesChange { await session.updateAllergies(selectedAllergies, customAllergy: selectedCustomAllergy) }
            if hasSkillLevelChange { await session.updateCookingSkillLevel(level: selectedSkillLevel) }

            isSaving = false
        }
    }
}

// MARK: - Edit sheet

enum ProfileField: String, Identifiable {
    case diet, restrictions, allergies, skill
    var id: String { rawValue }

    var title: String {
        switch self {
        case .diet: return "Dietary preference"
        case .restrictions: return "Dietary restrictions"
        case .allergies: return "Allergies"
        case .skill: return "Cooking skill"
        }
    }

    var note: String {
        switch self {
        case .diet: return "Your default diet when generating recipes."
        case .restrictions: return "Applied by default to every recipe."
        case .allergies: return "We'll keep these ingredients out of your recipes entirely."
        case .skill: return "Recipes are written for your level."
        }
    }
}

struct ProfileEditSheet: View {
    let field: ProfileField

    @Binding var selectedDietType: GenerationOptions.DietType
    @Binding var selectedRestrictions: Set<GenerationOptions.DietaryRestriction>
    @Binding var selectedAllergies: Set<AllergyType>
    @Binding var selectedCustomAllergy: String
    @Binding var showAllergyOtherField: Bool
    @Binding var selectedSkillLevel: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.rowInternals)

            HStack(alignment: .firstTextBaseline) {
                Text(field.title)
                    .sourdoughTextStyle(.title2)
                Spacer()
                Button("Done") { dismiss() }
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.actionInk)
                    .buttonStyle(.plain)
            }

            Text(field.note)
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                content
                    .padding(.top, Sourdough.Spacing.rowInternals)
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.canvas)
    }

    @ViewBuilder
    private func optionRow(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .sourdoughTextStyle(.body, color: isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                Spacer()
                if isSelected {
                    Ph.check.bold
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Sourdough.Colors.onAction)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
            .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch field {
        case .diet:
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(GenerationOptions.DietType.allCases) { type in
                    optionRow(type.rawValue, isSelected: selectedDietType == type) {
                        selectedDietType = type
                    }
                }
            }

        case .restrictions:
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                    let isSelected = selectedRestrictions.contains(restriction)
                    optionRow(restriction.rawValue, isSelected: isSelected) {
                        if isSelected { selectedRestrictions.remove(restriction) }
                        else { selectedRestrictions.insert(restriction) }
                    }
                }
            }

        case .allergies:
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(AllergyType.allCases) { allergy in
                    let isSelected = selectedAllergies.contains(allergy)
                    optionRow(allergy.rawValue, isSelected: isSelected) {
                        if isSelected { selectedAllergies.remove(allergy) }
                        else { selectedAllergies.insert(allergy) }
                    }
                }
                optionRow("Other", isSelected: showAllergyOtherField) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllergyOtherField.toggle()
                        if !showAllergyOtherField { selectedCustomAllergy = "" }
                    }
                }
                if showAllergyOtherField {
                    TextField("Type your allergy...", text: $selectedCustomAllergy)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .sourdoughTextStyle(.body)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 52)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

        case .skill:
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(AccountSettingsView.skillOptions, id: \.level) { option in
                    optionRow(option.label, isSelected: selectedSkillLevel == option.level) {
                        selectedSkillLevel = option.level
                    }
                }
            }
        }
    }
}

// MARK: - Username / Display name edit screen

enum ProfileTextField {
    case username, displayName

    var navTitle: String {
        switch self {
        case .username: return "Username"
        case .displayName: return "Display Name"
        }
    }

    var note: String {
        switch self {
        case .username: return "Your handle, shown publicly on shared recipes and reviews."
        case .displayName: return "Your full name, or how you'd like to be known."
        }
    }

    var placeholder: String {
        switch self {
        case .username: return "Enter a username"
        case .displayName: return "Enter a display name"
        }
    }
}

/// Pushed edit screen for username / display name — commits directly via `AppSession` and pops.
struct ProfileTextEditScreen: View {
    let field: ProfileTextField

    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSaving = false
    @State private var localError: String?

    private var currentValue: String {
        (field == .username ? session.currentUserNickname : session.currentUserDisplayName) ?? ""
    }

    private var cooldownMessage: String? {
        guard field == .username,
              let remaining = cooldownRemainingDays(since: session.nicknameUpdatedAt, cooldownDays: 30)
        else { return nil }
        return "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && !trimmed.isEmpty && trimmed != currentValue && cooldownMessage == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text(cooldownMessage ?? field.note)
                .sourdoughTextStyle(.caption, color: cooldownMessage != nil
                                    ? Sourdough.Ramp.honey600 : Sourdough.Colors.faintInk)

            TextField(field.placeholder, text: $text)
                .textInputAutocapitalization(field == .username ? .never : .words)
                .autocorrectionDisabled()
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .disabled(cooldownMessage != nil)
                .opacity(cooldownMessage != nil ? 0.5 : 1)

            if let localError {
                Text(localError)
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
            }

            Spacer()
        }
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.canvas)
        .navigationTitle(field.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preference(key: HideTabBarKey.self, value: true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            text = currentValue
            localError = nil
            session.nicknameError = nil
            session.profileUpdateError = nil
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        localError = nil

        switch field {
        case .username:
            await session.updateNickname(trimmed)
            if let e = session.nicknameError {
                localError = e
                session.nicknameError = nil
            } else {
                dismiss()
            }
        case .displayName:
            await session.updateDisplayName(trimmed)
            if let e = session.profileUpdateError {
                localError = e
                session.profileUpdateError = nil
            } else {
                dismiss()
            }
        }
    }
}
