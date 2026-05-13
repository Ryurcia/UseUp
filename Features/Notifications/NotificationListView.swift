import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss

    private var expiredItems: [Ingredient] {
        pantryStore.ingredients
            .filter { $0.isExpired && !pantryStore.dismissedIngredientIds.contains($0.id) }
            .sorted { ($0.expirationDate ?? .distantPast) < ($1.expirationDate ?? .distantPast) }
    }

    private var expiringSoonItems: [Ingredient] {
        pantryStore.ingredients
            .filter { !$0.isExpired && ($0.daysUntilExpiration ?? Int.max) <= 5 && !pantryStore.dismissedIngredientIds.contains($0.id) }
            .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
    }

    private var isEmpty: Bool {
        expiredItems.isEmpty && expiringSoonItems.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notifications")
                    .font(.custom("CalSans-Regular", size: 20))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DS.ColorToken.bgSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space3)

            if isEmpty {
                Spacer()
                VStack(spacing: DS.Spacing.space3) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.ColorToken.textTertiary)

                    Text("All clear!")
                        .font(.custom("Satoshi Variable", size: 18).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    Text("No expiring items right now.")
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                Spacer()
            } else {
                List {
                    if !expiredItems.isEmpty {
                        Section {
                            ForEach(expiredItems) { item in
                                notificationRow(item: item, color: DS.ColorToken.error, showRemove: true)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation { _ = pantryStore.dismissedIngredientIds.insert(item.id) }
                                        } label: {
                                            Text("Dismiss")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(DS.ColorToken.bgPrimary)
                            }
                        } header: {
                            sectionHeader(title: "Expired", icon: "exclamationmark.triangle.fill", color: DS.ColorToken.error, count: expiredItems.count)
                        }
                    }

                    if !expiringSoonItems.isEmpty {
                        Section {
                            ForEach(expiringSoonItems) { item in
                                notificationRow(item: item, color: DS.ColorToken.warning, showRemove: false)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation { _ = pantryStore.dismissedIngredientIds.insert(item.id) }
                                        } label: {
                                            Text("Dismiss")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(DS.ColorToken.bgPrimary)
                            }
                        } header: {
                            sectionHeader(title: "Expiring Soon", icon: "clock.fill", color: DS.ColorToken.warning, count: expiringSoonItems.count)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func sectionHeader(title: String, icon: String, color: Color, count: Int) -> some View {
        HStack(spacing: DS.Spacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(title)
                .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                .foregroundStyle(DS.ColorToken.textPrimary)
            Text("\(count)")
                .font(.custom("Satoshi Variable", size: 12).weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .textCase(nil)
    }

    private func notificationRow(item: Ingredient, color: Color, showRemove: Bool) -> some View {
        HStack(spacing: DS.Spacing.space3) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.capitalized)
                    .font(.custom("Satoshi Variable", size: 15).weight(.medium))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                HStack(spacing: DS.Spacing.space2) {
                    Text(item.location.title)
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)

                    Text("·")
                        .foregroundStyle(DS.ColorToken.textTertiary)

                    Text(expirationLabel(for: item))
                        .appTextStyle(.caption)
                        .foregroundStyle(color)
                }
            }

            Spacer()

            if showRemove {
                Button {
                    withAnimation {
                        pantryStore.deleteIngredient(id: item.id)
                    }
                } label: {
                    Text("Remove")
                        .font(.custom("Satoshi Variable", size: 12).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.error)
                        .padding(.horizontal, DS.Spacing.space3)
                        .padding(.vertical, DS.Spacing.space1)
                        .background(DS.ColorToken.errorLight)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.space3)
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private func expirationLabel(for item: Ingredient) -> String {
        guard let days = item.daysUntilExpiration else { return "No date" }
        if days < 0 { return "Expired \(abs(days)) day\(abs(days) == 1 ? "" : "s") ago" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
}
