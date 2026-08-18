import SwiftUI
import PhotosUI
import RevenueCatUI
import UserNotifications
import LocalAuthentication
import PhosphorSwift

#Preview("Account Settings") {
    PreviewContainer {
        NavigationStack {
            AccountSettingsView()
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @AppStorage("biometricLoginEnabled") private var biometricLoginEnabled = false
    @State private var notificationsAuthorized = false
    @State private var showClearCacheAlert = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $session.colorSchemePreference) {
                    Text("System").tag(ColorSchemePreference.system)
                    Text("Light").tag(ColorSchemePreference.light)
                    Text("Dark").tag(ColorSchemePreference.dark)
                }
                .pickerStyle(.segmented)
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: Binding(
                    get: { notificationsAuthorized },
                    set: { _ in handleNotificationToggle() }
                ))

                Toggle("Recipe Suggestions", isOn: $session.recipeSuggestionsEnabled)
                    .onChange(of: session.recipeSuggestionsEnabled) { _, newValue in
                        if newValue {
                            Task { await requestAuthorizationIfNeeded() }
                        }
                        Task { await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients) }
                    }

                if session.recipeSuggestionsEnabled && !notificationsAuthorized {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            Ph.warning.fill
                                .frame(width: 16, height: 16)
                                .foregroundStyle(Sourdough.Ramp.honey600)
                            Text("Notifications aren't enabled, so recipe suggestions won't be pushed to your device. You'll still see them in the Notifications tab.")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.caption)
                        }
                        Button("Enable Notifications") {
                            handleNotificationToggle()
                        }
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .sourdoughTextStyle(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Security") {
                Toggle("Log in with Face ID", isOn: $biometricLoginEnabled)
            }

            Section("Cache") {
                Button("Clear Image Cache") {
                    showClearCacheAlert = true
                }
                .foregroundStyle(Sourdough.Colors.ink)
            }

            Section {
                NavigationLink {
                    BlockedAccountsView()
                        .environmentObject(savedRecipesStore)
                } label: {
                    Label {
                        Text("Blocked Accounts")
                    } icon: {
                        Ph.prohibit.regular
                            .frame(width: 16, height: 16)
                    }
                        .foregroundStyle(Sourdough.Colors.ink)
                }
            }

            Section {
                Link(destination: URL(string: "https://www.useupnow.com/privacy")!) {
                    Label {
                        Text("Privacy Policy")
                    } icon: {
                        Ph.handPalm.regular
                            .frame(width: 16, height: 16)
                    }
                        .foregroundStyle(Sourdough.Colors.ink)
                }
                Link(destination: URL(string: "https://www.useupnow.com/terms")!) {
                    Label {
                        Text("Terms & Conditions")
                    } icon: {
                        Ph.fileText.regular
                            .frame(width: 16, height: 16)
                    }
                        .foregroundStyle(Sourdough.Colors.ink)
                }
            }

            Section {
                Button {
                    session.signOut()
                } label: {
                    Label {
                        Text("Sign Out")
                    } icon: {
                        Ph.signOut.regular
                            .frame(width: 16, height: 16)
                    }
                        .foregroundStyle(Sourdough.Colors.destructive)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Clear Image Cache", isPresented: $showClearCacheAlert) {
            Button("Clear", role: .destructive) {
                RecipeImageCache.shared.clear()
                RecipeImageDiskCache.clear()
                AvatarCache.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All cached images will be removed and re-downloaded when needed.")
        }
        .task {
            await refreshNotificationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    private func handleNotificationToggle() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                await requestAuthorizationIfNeeded()
            } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        }
    }

    private func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        notificationsAuthorized = granted
    }
}

// MARK: - Blocked Accounts

struct BlockedAccountsView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true
    @State private var unblockError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blockedUsers.isEmpty {
                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.prohibit.regular
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    Text("No blocked accounts")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack {
                            Text(user.nickname)
                                .foregroundStyle(Sourdough.Colors.ink)
                            Spacer()
                            Button("Unblock") {
                                Task {
                                    do {
                                        try await savedRecipesStore.unblockUser(user.id)
                                        blockedUsers.removeAll { $0.id == user.id }
                                    } catch {
                                        unblockError = "Failed to unblock user. Please try again."
                                    }
                                }
                            }
                            .foregroundStyle(Sourdough.Ramp.sage600)
                        }
                    }
                }
            }
        }
        .navigationTitle("Blocked Accounts")
        .task {
            blockedUsers = await savedRecipesStore.fetchBlockedUsers()
            isLoading = false
        }
        .alert("Error", isPresented: Binding(
            get: { unblockError != nil },
            set: { if !$0 { unblockError = nil } }
        )) {
            Button("OK") { unblockError = nil }
        } message: {
            if let err = unblockError { Text(err) }
        }
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @EnvironmentObject private var session: AppSession

    // Profile editing state
    @State private var nicknameText = ""
    @State private var displayNameText = ""
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
    @State private var showCustomerCenter = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    private var nicknameChanged: Bool {
        nicknameText.trimmingCharacters(in: .whitespacesAndNewlines) != (session.currentUserNickname ?? "")
    }

    private var displayNameChanged: Bool {
        displayNameText.trimmingCharacters(in: .whitespacesAndNewlines) != (session.currentUserDisplayName ?? "")
    }

    private var dietaryCooldownDaysRemaining: Int? {
        cooldownRemainingDays(since: session.dietaryUpdatedAt, cooldownDays: 15)
    }

    private var dietaryCooldownMessage: String? {
        guard let remaining = dietaryCooldownDaysRemaining else { return nil }
        return "You can change your diet & restrictions again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var cooldownMessage: String? {
        guard let remaining = cooldownRemainingDays(since: session.nicknameUpdatedAt, cooldownDays: 30) else { return nil }
        return "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var hasChanges: Bool {
        selectedImage != nil
        || nicknameChanged
        || displayNameChanged
        || selectedDietType != session.currentUserDietaryPreference
        || selectedRestrictions != session.currentUserDietaryRestrictions
        || selectedAllergies != session.currentUserAllergies
        || selectedCustomAllergy != session.currentUserCustomAllergy
        || selectedSkillLevel != session.currentUserCookingSkillLevel
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                profilePictureSection
                nicknameSection
                displayNameSection
                dietaryPreferenceSection
                dietaryRestrictionsSection
                allergiesSection
                if let message = dietaryCooldownMessage {
                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        Ph.clock.fill
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Sourdough.Ramp.honey600)
                        Text(message)
                            .foregroundStyle(Sourdough.Ramp.honey600)
                            .sourdoughTextStyle(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                cookingSkillSection
                saveButtonSection
                Divider().padding(.vertical, Sourdough.Spacing.insideChip)
                emailSection
                membershipSection
                deleteAccountSection
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.underTitle * 2)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nicknameText = session.currentUserNickname ?? ""
            displayNameText = session.currentUserDisplayName ?? ""
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
        .alert("Error", isPresented: Binding(
            get: { saveError != nil || session.profileUpdateError != nil },
            set: { if !$0 { saveError = nil; session.profileUpdateError = nil } }
        )) {
            Button("OK") { saveError = nil; session.profileUpdateError = nil }
        } message: {
            Text(saveError ?? session.profileUpdateError ?? "")
        }
        .sheet(isPresented: $showPaywall) {
            UseUpPaywallView { showPaywall = false }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
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

    // MARK: - Sections

    @ViewBuilder private var profilePictureSection: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Button { showPhotosPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let data = session.profileImageData,
                              let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Ph.userCircle.fill
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Sourdough.Ramp.sage500)
                            .frame(width: 100, height: 100)
                    }
                    Ph.camera.fill
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .frame(width: 28, height: 28)
                        .background(Sourdough.Colors.action)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Sourdough.Colors.canvas, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            Text("Tap to change photo")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Sourdough.Spacing.insideChip)
    }

    @ViewBuilder private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Nickname")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            TextField("Enter a nickname", text: $nicknameText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .disabled(cooldownMessage != nil)
            if let cooldown = cooldownMessage {
                Text(cooldown).foregroundStyle(Sourdough.Ramp.honey600).sourdoughTextStyle(.caption)
            } else {
                Text("This is how you're greeted on the home screen.").foregroundStyle(Sourdough.Colors.faintInk).sourdoughTextStyle(.caption)
            }
            if let error = session.nicknameError {
                Text(error).foregroundStyle(Sourdough.Colors.destructive).sourdoughTextStyle(.caption)
            }
        }
    }

    @ViewBuilder private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Display Name")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            TextField("Enter a display name", text: $displayNameText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            Text("Your full name or how you'd like to be known.")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
    }

    @ViewBuilder private var dietaryPreferenceSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Dietary Preference")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                ForEach(GenerationOptions.DietType.allCases) { dietType in
                    SelectableChip(label: dietType.rawValue, isSelected: selectedDietType == dietType) {
                        selectedDietType = dietType
                    }
                }
            }
            Text("Used as your default diet when generating recipes.")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
        .opacity(dietaryCooldownDaysRemaining != nil ? 0.5 : 1)
        .disabled(dietaryCooldownDaysRemaining != nil)
    }

    @ViewBuilder private var dietaryRestrictionsSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Dietary Restrictions")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                    let isSelected = selectedRestrictions.contains(restriction)
                    SelectableChip(label: restriction.rawValue, isSelected: isSelected) {
                        if isSelected { selectedRestrictions.remove(restriction) }
                        else { selectedRestrictions.insert(restriction) }
                    }
                }
            }
            Text("Applied by default when generating recipes.")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
        .opacity(dietaryCooldownDaysRemaining != nil ? 0.5 : 1)
        .disabled(dietaryCooldownDaysRemaining != nil)
    }

    @ViewBuilder private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Allergies")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                ForEach(AllergyType.allCases) { allergy in
                    let isSelected = selectedAllergies.contains(allergy)
                    SelectableChip(label: allergy.rawValue, isSelected: isSelected) {
                        if isSelected { selectedAllergies.remove(allergy) }
                        else { selectedAllergies.insert(allergy) }
                    }
                }
                SelectableChip(label: "Other", isSelected: showAllergyOtherField) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllergyOtherField.toggle()
                        if !showAllergyOtherField { selectedCustomAllergy = "" }
                    }
                }
            }
            if showAllergyOtherField {
                TextField("Type your allergy...", text: $selectedCustomAllergy)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .frame(height: 52)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("We'll use this to keep unsafe ingredients out of your recipes.")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
    }

    @ViewBuilder private var cookingSkillSection: some View {
        let skillOptions: [(level: Int, label: String)] = [
            (1, "I'd rather order in"),
            (2, "I can cook a decent meal"),
            (3, "Just call me Gordon Ramsay"),
        ]
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Cooking Skill Level")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(skillOptions, id: \.level) { option in
                    let isSelected = selectedSkillLevel == option.level
                    Button { selectedSkillLevel = option.level } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.caption)
                            Spacer()
                            if isSelected {
                                Ph.check.bold
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(Sourdough.Colors.onAction)
                            }
                        }
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .padding(.vertical, Sourdough.Spacing.rowInternals)
                        .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                        .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous).stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Recipes will be tailored to your skill level.")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
    }

    @ViewBuilder private var saveButtonSection: some View {
        Button { save() } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                if isSaving { ProgressView().tint(Sourdough.Colors.onAction) }
                Text("Save Changes")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.rowTitle)
            }
            .foregroundStyle(Sourdough.Colors.onAction)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(hasChanges ? Sourdough.Colors.action : Sourdough.Colors.action.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving || !hasChanges)
    }

    @ViewBuilder private var emailSection: some View {
        profileCard(header: "Email") {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Ph.envelope.fill
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Sourdough.Colors.actionInk)
                    .frame(width: 24)
                Text(session.currentUserEmail ?? "No email")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                Spacer()
            }
            .padding(Sourdough.Spacing.screenMargin)
        }
    }

    @ViewBuilder private var membershipSection: some View {
        profileCard(header: "Membership Plan") {
            VStack(spacing: Sourdough.Spacing.rowInternals) {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    (session.isPremium ? Ph.sparkle.regular : Ph.leaf.fill)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(session.isPremium ? Sourdough.Colors.actionInk : Sourdough.Ramp.sage500)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.isPremium ? "UseUp Pro" : "Free Plan")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.body)
                        Text(session.isPremium ? "Full access to all features" : "Basic pantry tracking & recipe browsing")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                    }
                    Spacer()
                    Text("Active")
                        .foregroundStyle(Sourdough.Ramp.sage600)
                        .sourdoughTextStyle(.sectionHead)
                        .padding(.horizontal, Sourdough.Spacing.insideChip)
                        .padding(.vertical, 4)
                        .background(Sourdough.Ramp.sage100)
                        .clipShape(Capsule())
                }
                if session.isPremium {
                    Button { showCustomerCenter = true } label: {
                        Text("Manage Subscription")
                            .foregroundStyle(Sourdough.Colors.actionInk)
                            .sourdoughTextStyle(.caption)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Sourdough.Ramp.terracotta100)
                            .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous).stroke(Sourdough.Colors.actionInk.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showPaywall = true } label: {
                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            Ph.sparkle.regular.frame(width: 14, height: 14)
                            Text("Upgrade to Pro")
                                .foregroundStyle(Sourdough.Colors.onAction)
                                .sourdoughTextStyle(.caption)
                        }
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(LinearGradient(colors: [Sourdough.Colors.action, Sourdough.Ramp.terracotta400], startPoint: .topTrailing, endPoint: .bottomLeading))
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { try? await RevenueCatManager.shared.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Sourdough.Spacing.screenMargin)
        }
    }

    @ViewBuilder private var deleteAccountSection: some View {
        profileCard(header: "Danger Zone") {
            Button {
                showDeleteAccountAlert = true
            } label: {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.trash.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Sourdough.Colors.destructive)
                    Text(isDeletingAccount ? "Deleting…" : "Delete Account")
                        .foregroundStyle(Sourdough.Colors.destructive)
                        .sourdoughTextStyle(.body)
                    Spacer()
                }
                .padding(Sourdough.Spacing.screenMargin)
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
        }
    }

    private func save() {
        let hasNewPhoto = selectedImage != nil
        let hasNicknameChange = nicknameChanged
        let hasDisplayNameChange = displayNameChanged
        let hasDietChange = selectedDietType != session.currentUserDietaryPreference
        let hasRestrictionsChange = selectedRestrictions != session.currentUserDietaryRestrictions
        let hasAllergiesChange = selectedAllergies != session.currentUserAllergies || selectedCustomAllergy != session.currentUserCustomAllergy
        let hasSkillLevelChange = selectedSkillLevel != session.currentUserCookingSkillLevel

        guard hasNewPhoto || hasNicknameChange || hasDisplayNameChange || hasDietChange || hasRestrictionsChange || hasAllergiesChange || hasSkillLevelChange else { return }

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
            if hasNicknameChange {
                let cleaned = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { await session.updateNickname(cleaned) }
            }
            if hasDisplayNameChange {
                await session.updateDisplayName(displayNameText)
            }
            if hasDietChange { await session.updateDietaryPreference(dietType: selectedDietType) }
            if hasRestrictionsChange { await session.updateDietaryRestrictions(restrictions: selectedRestrictions) }
            if hasAllergiesChange { await session.updateAllergies(selectedAllergies, customAllergy: selectedCustomAllergy) }
            if hasSkillLevelChange { await session.updateCookingSkillLevel(level: selectedSkillLevel) }

            isSaving = false
        }
    }

    @ViewBuilder
    private func profileCard<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text(header)
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.sectionHead)
                .padding(.leading, 4)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                        .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        }
    }
}

