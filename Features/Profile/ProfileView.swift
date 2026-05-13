import SwiftUI
import RevenueCatUI
import UserNotifications

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
    @State private var notificationsAuthorized = false
    @State private var showClearCacheAlert = false

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $session.isDarkMode)
            }

            Section("Notifications") {
                Toggle("Expiration Reminders", isOn: Binding(
                    get: { notificationsAuthorized },
                    set: { _ in handleNotificationToggle() }
                ))
            }

            Section("Cache") {
                Button("Clear Image Cache") {
                    showClearCacheAlert = true
                }
                .foregroundStyle(DS.ColorToken.textPrimary)
            }

            Section {
                Button {
                    session.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(DS.ColorToken.error)
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
        .task { await refreshNotificationStatus() }
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
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                notificationsAuthorized = granted
            } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
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
    @State private var selectedSkillLevel: Int = 1
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    // Account state
    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    private var nicknameChanged: Bool {
        nicknameText.trimmingCharacters(in: .whitespacesAndNewlines) != (session.currentUserNickname ?? "")
    }

    private var displayNameChanged: Bool {
        displayNameText.trimmingCharacters(in: .whitespacesAndNewlines) != (session.currentUserDisplayName ?? "")
    }

    private var dietaryCooldownDaysRemaining: Int? {
        guard let updatedAt = session.dietaryUpdatedAt else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
        let remaining = 15 - daysSince
        return remaining > 0 ? remaining : nil
    }

    private var dietaryCooldownMessage: String? {
        guard let remaining = dietaryCooldownDaysRemaining else { return nil }
        return "You can change your diet & restrictions again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var cooldownMessage: String? {
        guard let updatedAt = session.nicknameUpdatedAt else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
        let remaining = 30 - daysSince
        guard remaining > 0 else { return nil }
        return "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    private var hasChanges: Bool {
        selectedImage != nil
        || nicknameChanged
        || displayNameChanged
        || selectedDietType != session.currentUserDietaryPreference
        || selectedRestrictions != session.currentUserDietaryRestrictions
        || selectedSkillLevel != session.currentUserCookingSkillLevel
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.space6) {

                // MARK: Profile Picture
                VStack(spacing: DS.Spacing.space3) {
                    Button { showImagePicker = true } label: {
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
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(DS.ColorToken.accent)
                                    .frame(width: 100, height: 100)
                            }

                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(DS.ColorToken.primary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(DS.ColorToken.bgPrimary, lineWidth: 2))
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Tap to change photo")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.space2)

                // MARK: Nickname
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Nickname")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    TextField("Enter a nickname", text: $nicknameText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.custom("Satoshi Variable", size: 16))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 52)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                        .disabled(cooldownMessage != nil)

                    if let cooldown = cooldownMessage {
                        Text(cooldown)
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.warning)
                    } else {
                        Text("This is how you're greeted on the home screen.")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textTertiary)
                    }

                    if let error = session.nicknameError {
                        Text(error)
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.error)
                    }
                }

                // MARK: Display Name
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Display Name")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    TextField("Enter a display name", text: $displayNameText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.custom("Satoshi Variable", size: 16))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 52)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                    Text("Your full name or how you'd like to be known.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }

                // MARK: Dietary Preference
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Dietary Preference")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietType.allCases) { dietType in
                            Button { selectedDietType = dietType } label: {
                                Text(dietType.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(
                                        selectedDietType == dietType ? .white : DS.ColorToken.textSecondary
                                    )
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(
                                        selectedDietType == dietType
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedDietType == dietType ? Color.clear : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Used as your default diet when generating recipes.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .opacity(dietaryCooldownDaysRemaining != nil ? 0.5 : 1)
                .disabled(dietaryCooldownDaysRemaining != nil)

                // MARK: Dietary Restrictions
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Dietary Restrictions")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                            let isSelected = selectedRestrictions.contains(restriction)
                            Button {
                                if isSelected { selectedRestrictions.remove(restriction) }
                                else { selectedRestrictions.insert(restriction) }
                            } label: {
                                Text(restriction.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(isSelected ? DS.ColorToken.primary : DS.ColorToken.bgSecondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color.clear : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Applied by default when generating recipes.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .opacity(dietaryCooldownDaysRemaining != nil ? 0.5 : 1)
                .disabled(dietaryCooldownDaysRemaining != nil)

                if let message = dietaryCooldownMessage {
                    HStack(spacing: DS.Spacing.space2) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.ColorToken.warning)
                        Text(message)
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // MARK: Cooking Skill Level
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Cooking Skill Level")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    let skillOptions: [(level: Int, label: String)] = [
                        (1, "I cook like I'm in college"),
                        (2, "I can cook a decent meal"),
                        (3, "Just call me Gordon Ramsay"),
                    ]

                    VStack(spacing: DS.Spacing.space2) {
                        ForEach(skillOptions, id: \.level) { option in
                            let isSelected = selectedSkillLevel == option.level
                            Button { selectedSkillLevel = option.level } label: {
                                HStack {
                                    Text(option.label)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.space3)
                                .padding(.vertical, DS.Spacing.space3)
                                .background(isSelected ? DS.ColorToken.primary : DS.ColorToken.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                        .stroke(
                                            isSelected ? Color.clear : DS.ColorToken.borderDefault,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Recipes will be tailored to your skill level.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }

                // MARK: Save Button
                Button { save() } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        if isSaving { ProgressView().tint(.white) }
                        Text("Save Changes")
                    }
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(hasChanges ? DS.ColorToken.primary : DS.ColorToken.primary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || !hasChanges)

                Divider()
                    .padding(.vertical, DS.Spacing.space2)

                // MARK: Phone
                profileCard(header: "Phone") {
                    HStack(spacing: DS.Spacing.space3) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.ColorToken.primary)
                            .frame(width: 24)

                        Text(session.currentUserPhone ?? "No phone")
                            .font(.custom("Satoshi Variable", size: 16))
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        Spacer()
                    }
                    .padding(DS.Spacing.space4)
                }

                // MARK: Membership Plan
                profileCard(header: "Membership Plan") {
                    VStack(spacing: DS.Spacing.space3) {
                        HStack(spacing: DS.Spacing.space3) {
                            Image(systemName: session.isPremium ? "sparkles" : "leaf.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(session.isPremium ? DS.ColorToken.primary : DS.ColorToken.accent)

                            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                                Text(session.isPremium ? "UseUp Pro" : "Free Plan")
                                    .font(.custom("Satoshi Variable", size: 16))
                                    .foregroundStyle(DS.ColorToken.textPrimary)

                                Text(session.isPremium ? "Full access to all features" : "Basic pantry tracking & recipe browsing")
                                    .appTextStyle(.caption)
                                    .foregroundStyle(DS.ColorToken.textSecondary)
                            }

                            Spacer()

                            Text("Active")
                                .appTextStyle(.overline)
                                .foregroundStyle(DS.ColorToken.accent)
                                .padding(.horizontal, DS.Spacing.space2)
                                .padding(.vertical, DS.Spacing.space1)
                                .background(DS.ColorToken.accentLight)
                                .clipShape(Capsule())
                        }

                        if session.isPremium {
                            Button { showCustomerCenter = true } label: {
                                Text("Manage Subscription")
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(DS.ColorToken.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(DS.ColorToken.primaryLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                            .stroke(DS.ColorToken.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button { showPaywall = true } label: {
                                HStack(spacing: DS.Spacing.space2) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Upgrade to Pro")
                                        .font(.custom("Satoshi Variable", size: 14))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { try? await RevenueCatManager.shared.restorePurchases() }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.custom("Satoshi Variable", size: 13))
                                    .foregroundStyle(DS.ColorToken.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DS.Spacing.space4)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space4)
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nicknameText = session.currentUserNickname ?? ""
            displayNameText = session.currentUserDisplayName ?? ""
            selectedDietType = session.currentUserDietaryPreference
            selectedRestrictions = session.currentUserDietaryRestrictions
            selectedSkillLevel = session.currentUserCookingSkillLevel
            session.nicknameError = nil
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in showPaywall = false }
                .onRestoreCompleted { _ in showPaywall = false }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
    }

    private func save() {
        let hasNewPhoto = selectedImage != nil
        let hasNicknameChange = nicknameChanged
        let hasDisplayNameChange = displayNameChanged
        let hasDietChange = selectedDietType != session.currentUserDietaryPreference
        let hasRestrictionsChange = selectedRestrictions != session.currentUserDietaryRestrictions
        let hasSkillLevelChange = selectedSkillLevel != session.currentUserCookingSkillLevel

        guard hasNewPhoto || hasNicknameChange || hasDisplayNameChange || hasDietChange || hasRestrictionsChange || hasSkillLevelChange else { return }

        Task {
            isSaving = true

            if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.8) {
                await session.updateProfilePhoto(data)
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
            if hasSkillLevelChange { await session.updateCookingSkillLevel(level: selectedSkillLevel) }

            isSaving = false
        }
    }

    @ViewBuilder
    private func profileCard<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space2) {
            Text(header)
                .appTextStyle(.overline)
                .foregroundStyle(DS.ColorToken.textTertiary)
                .padding(.leading, DS.Spacing.space1)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.ColorToken.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        }
    }
}

// MARK: - Image Picker

private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
