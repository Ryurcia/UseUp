import SwiftUI

#Preview("Profile") {
    PreviewContainer {
        NavigationStack {
            ProfileView()
        }
    }
}

private enum StatPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedPeriod: StatPeriod = .week

    private var profileDisplayName: String {
        if let name = session.currentUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let nickname = session.currentUserNickname?.trimmingCharacters(in: .whitespacesAndNewlines),
           !nickname.isEmpty {
            return nickname
        }
        return "Guest"
    }

    private var statsForPeriod: (foodSaved: String, recipesCooked: String, wastePrevented: String) {
        switch selectedPeriod {
        case .week: return ("4 items", "3 recipes", "0.8 kg")
        case .month: return ("12 items", "8 recipes", "2.4 kg")
        case .year: return ("87 items", "52 recipes", "18.6 kg")
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.space5) {
                // Header
                VStack(spacing: DS.Spacing.space2) {
                    if let data = session.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(DS.ColorToken.accent)
                    }

                    Text(profileDisplayName)
                        .font(.custom("CalSans-Regular", size: 28))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    if let nickname = session.currentUserNickname?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !nickname.isEmpty {
                        Text("@\(nickname)")
                            .font(.custom("Satoshi Variable", size: 15).weight(.medium))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }


                    NavigationLink {
                        EditProfileView()
                    } label: {
                        HStack(spacing: DS.Spacing.space1) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Edit Profile")
                                .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                        }
                        .foregroundStyle(DS.ColorToken.primary)
                        .padding(.horizontal, DS.Spacing.space4)
                        .frame(height: 36)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            Capsule()
                                .stroke(DS.ColorToken.primary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DS.Spacing.space1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.space6)

                // Stats section
                VStack(spacing: DS.Spacing.space3) {
                    // Period toggle
                    HStack(spacing: 0) {
                        ForEach(StatPeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPeriod = period
                                }
                            } label: {
                                Text(period.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14).weight(selectedPeriod == period ? .bold : .regular))
                                    .foregroundStyle(
                                        selectedPeriod == period
                                            ? DS.ColorToken.accent
                                            : DS.ColorToken.textTertiary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(
                                        selectedPeriod == period
                                            ? DS.ColorToken.accentLight
                                            : Color.clear
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DS.Spacing.space1)
                    .background(DS.ColorToken.bgSecondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DS.ColorToken.borderDefault, lineWidth: 0.5)
                    )

                    // Stats cards
                    HStack(spacing: DS.Spacing.space3) {
                        statCard(value: statsForPeriod.foodSaved, label: "Food Saved", icon: "leaf.fill", color: DS.ColorToken.accent)
                        statCard(value: statsForPeriod.recipesCooked, label: "Recipes Cooked", icon: "fork.knife", color: DS.ColorToken.primary)
                        statCard(value: statsForPeriod.wastePrevented, label: "Waste Prevented", icon: "arrow.3.trianglepath", color: DS.ColorToken.ocean)
                    }
                }

                // Backend status card
                profileSection(header: "Backend Status") {
                    HStack(spacing: DS.Spacing.space3) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.ColorToken.warning)
                            .frame(width: 24)

                        Text("Supabase and live AI generation are not connected yet.")
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }
                    .padding(DS.Spacing.space4)
                }

            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text(label)
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.space4)
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func profileSection<Content: View>(header: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space2) {
            if let header {
                Text(header)
                    .appTextStyle(.overline)
                    .foregroundStyle(DS.ColorToken.textTertiary)
                    .padding(.leading, DS.Spacing.space1)
            }

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

// MARK: - Edit Profile

struct EditProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var nicknameText = ""
    @State private var selectedDietType: GenerationOptions.DietType = .any
    @State private var selectedRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    private var nicknameChanged: Bool {
        let cleaned = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned != (session.currentUserNickname ?? "")
    }

    private var dietChanged: Bool {
        selectedDietType != session.currentUserDietaryPreference
    }

    private var restrictionsChanged: Bool {
        selectedRestrictions != session.currentUserDietaryRestrictions
    }

    private var cooldownMessage: String? {
        guard let updatedAt = session.nicknameUpdatedAt else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
        let remaining = 30 - daysSince
        guard remaining > 0 else { return nil }
        return "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.space6) {
                // Profile picture
                VStack(spacing: DS.Spacing.space3) {
                    Button {
                        showImagePicker = true
                    } label: {
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
                                .overlay(
                                    Circle()
                                        .stroke(DS.ColorToken.bgPrimary, lineWidth: 2)
                                )
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Tap to change photo")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.space4)

                // Nickname
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

                // Dietary Preference
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Dietary Preference")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietType.allCases) { dietType in
                            Button {
                                selectedDietType = dietType
                            } label: {
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
                                                selectedDietType == dietType
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("This is used as your default diet when generating recipes.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }

                // Dietary Restrictions
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Dietary Restrictions")
                        .font(.custom("CalSans-Regular", size: 14))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    FlowLayout(spacing: DS.Spacing.space2) {
                        ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                            let isSelected = selectedRestrictions.contains(restriction)
                            Button {
                                if isSelected {
                                    selectedRestrictions.remove(restriction)
                                } else {
                                    selectedRestrictions.insert(restriction)
                                }
                            } label: {
                                Text(restriction.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(
                                        isSelected ? .white : DS.ColorToken.textSecondary
                                    )
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space2)
                                    .background(
                                        isSelected
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("These are applied by default when generating recipes.")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }

                // Save button
                Button {
                    save()
                } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Save Changes")
                    }
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onAppear {
            nicknameText = session.currentUserNickname ?? ""
            selectedDietType = session.currentUserDietaryPreference
            selectedRestrictions = session.currentUserDietaryRestrictions
            session.nicknameError = nil
        }
    }

    private func save() {
        let hasNewPhoto = selectedImage != nil
        let hasNicknameChange = nicknameChanged
        let hasDietChange = dietChanged
        let hasRestrictionsChange = restrictionsChanged

        guard hasNewPhoto || hasNicknameChange || hasDietChange || hasRestrictionsChange else {
            dismiss()
            return
        }

        Task {
            isSaving = true

            if let selectedImage, let data = selectedImage.jpegData(compressionQuality: 0.8) {
                await session.updateProfilePhoto(data)
            }

            if hasNicknameChange {
                let cleaned = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    await session.updateNickname(cleaned)
                }
            }

            if hasDietChange {
                await session.updateDietaryPreference(dietType: selectedDietType)
            }

            if hasRestrictionsChange {
                await session.updateDietaryRestrictions(restrictions: selectedRestrictions)
            }

            isSaving = false

            if session.nicknameError == nil {
                dismiss()
            }
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

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $session.isDarkMode)
            }

            Section {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label("Account Settings", systemImage: "person.crop.circle")
                }
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
    }
}

// MARK: - Account Settings

private struct AccountSettingsView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.space5) {
                // Phone
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


                // Membership Plan
                profileCard(header: "Membership Plan") {
                    VStack(spacing: DS.Spacing.space3) {
                        HStack(spacing: DS.Spacing.space3) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DS.ColorToken.accent)

                            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                                Text("Free Plan")
                                    .font(.custom("Satoshi Variable", size: 16))
                                    .foregroundStyle(DS.ColorToken.textPrimary)

                                Text("Basic pantry tracking & recipe browsing")
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

                        Button {
                            // TODO: upgrade flow
                        } label: {
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
                    }
                    .padding(DS.Spacing.space4)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
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
