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

    private var displayName: String {
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

                    Text(displayName)
                        .font(.custom("CalSans-Regular", size: 28))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    if let phone = session.currentUserPhone {
                        Text(phone)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textTertiary)
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
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    private var nicknameChanged: Bool {
        let cleaned = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned != (session.currentUserNickname ?? "")
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
            session.nicknameError = nil
        }
    }

    private func save() {
        if let selectedImage, let data = selectedImage.jpegData(compressionQuality: 0.8) {
            session.profileImageData = data
        }

        if nicknameChanged {
            let cleaned = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                dismiss()
                return
            }
            Task {
                isSaving = true
                await session.updateNickname(cleaned)
                isSaving = false
                if session.nicknameError == nil {
                    dismiss()
                }
            }
        } else {
            dismiss()
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
    @State private var showChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var passwordSuccess = false

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

                // Change Password
                profileCard(header: "Password") {
                    VStack(spacing: DS.Spacing.space3) {
                        if showChangePassword {
                            passwordField(label: "Current Password", text: $currentPassword)
                            passwordField(label: "New Password", text: $newPassword)
                            passwordField(label: "Confirm New Password", text: $confirmPassword)

                            if let passwordError {
                                Text(passwordError)
                                    .appTextStyle(.bodySM)
                                    .foregroundStyle(DS.ColorToken.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if passwordSuccess {
                                Text("Password updated successfully.")
                                    .appTextStyle(.bodySM)
                                    .foregroundStyle(DS.ColorToken.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack(spacing: DS.Spacing.space3) {
                                Button {
                                    showChangePassword = false
                                    resetPasswordFields()
                                } label: {
                                    Text("Cancel")
                                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                        .foregroundStyle(DS.ColorToken.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(DS.ColorToken.bgPrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    submitPasswordChange()
                                } label: {
                                    Text("Update")
                                        .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(DS.ColorToken.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button {
                                showChangePassword = true
                            } label: {
                                HStack(spacing: DS.Spacing.space2) {
                                    Image(systemName: "lock.rotation")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Change Password")
                                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                }
                                .foregroundStyle(DS.ColorToken.primary)
                            }
                            .buttonStyle(.plain)
                        }
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

    private func passwordField(label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(.custom("Satoshi Variable", size: 16))
            .foregroundStyle(DS.ColorToken.textPrimary)
            .padding(.horizontal, DS.Spacing.space3)
            .frame(height: 48)
            .background(DS.ColorToken.bgPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
    }

    private func submitPasswordChange() {
        passwordError = nil
        passwordSuccess = false

        guard !currentPassword.isEmpty else {
            passwordError = "Enter your current password."
            return
        }
        guard newPassword.count >= 6 else {
            passwordError = "New password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = "Passwords do not match."
            return
        }

        // TODO: call auth service to change password
        passwordSuccess = true
        resetPasswordFields()
    }

    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
    }
}
