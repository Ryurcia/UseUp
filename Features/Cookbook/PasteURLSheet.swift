import SwiftUI

struct PasteURLSheet: View {
    var onImported: (RecipeImportData) -> Void

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    private let importer = RecipeURLImporter()

    var body: some View {
        VStack(spacing: DS.Spacing.space4) {
            Spacer()

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                Text("Recipe URL")
                    .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                    .foregroundStyle(DS.ColorToken.textSecondary)

                HStack(spacing: DS.Spacing.space2) {
                    Image(systemName: "link")
                        .foregroundStyle(DS.ColorToken.textTertiary)
                    TextField("https://", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .onSubmit { importURL() }
                    if !urlText.isEmpty {
                        Button { urlText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DS.ColorToken.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.space3)
                .frame(height: 48)
                .background(DS.ColorToken.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                        .stroke(errorMessage != nil ? DS.ColorToken.error : DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                if let error = errorMessage {
                    Text(error)
                        .font(.custom("Satoshi Variable", size: 12))
                        .foregroundStyle(DS.ColorToken.error)
                        .padding(.horizontal, DS.Spacing.space2)
                }
            }

            Button(action: importURL) {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Import Recipe")
                            .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
                    ? DS.ColorToken.bgSecondary
                    : DS.ColorToken.accent)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ColorToken.bgPrimary)
    }

    private func importURL() {
        errorMessage = nil
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let result = try await importer.importRecipe(from: trimmed)
                onImported(result)
            } catch let e as RecipeImportError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }
}
