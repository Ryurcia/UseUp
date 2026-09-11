import SwiftUI
import PhosphorSwift

/// Pushed edit screen for changing the account password — styled like `ProfileTextEditScreen`
/// (title/note, pill-shaped `Sourdough.Colors.sunken` fields, toolbar Save button). Requires the
/// current password, verified via a live sign-in in `AppSession.changePassword`.
struct ChangePasswordView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isSaving = false

    private var canSave: Bool {
        !isSaving
        && !currentPassword.isEmpty
        && newPassword.count >= 6
        && newPassword == confirmPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text("Enter your current password, then choose a new one.")
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)

            SecureField("Current password", text: $currentPassword)
                .textContentType(.password)
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .onChange(of: currentPassword) { _, _ in session.authError = nil }

            HStack(spacing: Sourdough.Spacing.insideChip) {
                Group {
                    if isPasswordVisible {
                        TextField("New password", text: $newPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("New password", text: $newPassword)
                    }
                }
                .textContentType(.newPassword)
                .sourdoughTextStyle(.body)
                .onChange(of: newPassword) { _, _ in session.authError = nil }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    (isPasswordVisible ? Ph.eyeSlash.regular : Ph.eye.regular)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 52)
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

            SecureField("Confirm new password", text: $confirmPassword)
                .textContentType(.newPassword)
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .onChange(of: confirmPassword) { _, _ in session.authError = nil }

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("Passwords don't match.")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
            }

            if let error = session.authError {
                Text(error)
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
            }

            Spacer()
        }
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .preference(key: HideTabBarKey.self, value: true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            session.authError = nil
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        await session.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        if session.authError == nil {
            dismiss()
        }
    }
}
