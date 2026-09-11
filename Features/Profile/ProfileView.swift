import SwiftUI
import PhotosUI
import UserNotifications
import PhosphorSwift

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var userActivityStore: UserActivityStore
    @EnvironmentObject private var statsStore: StatsStore
    @State private var showClearCacheAlert = false
    @State private var isExportingData = false
    @State private var exportedFileURLs: [URL] = []
    @State private var showExportShare = false
    @State private var showExportError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                settingsGroup("Preferences", footer: "Theme and notifications apply to this device.") {
                    themeRow
                    settingsNavRow(icon: Ph.bell.regular, tint: Sourdough.Ramp.sage100, ink: Sourdough.Ramp.sage600,
                                   label: "Notifications", first: false) {
                        NotificationSettingsView()
                    }
                }

                settingsGroup("Cache", footer: "Cached recipe photos are re-downloaded automatically when needed.") {
                    settingsRow(icon: Ph.trash.regular, tint: Sourdough.Ramp.linen100, ink: Sourdough.Ramp.linen500,
                                label: "Clear Image Cache", first: true) {
                        showClearCacheAlert = true
                    }
                }

                settingsGroup("Data", footer: "Download a copy of everything Use Up stores about you, as CSV files.") {
                    exportDataRow
                }

                blockedAccountsRow
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.betweenBlocks)
            .padding(.bottom, Sourdough.Spacing.underTitle)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Settings")
        .preference(key: HideTabBarKey.self, value: true)
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
        .sheet(isPresented: $showExportShare) {
            ShareSheet(items: exportedFileURLs)
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text("Couldn't export your data. Please try again.")
        }
    }

    private var exportDataRow: some View {
        Button {
            Task { await exportData() }
        } label: {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Ph.export.regular
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Sourdough.Ramp.sage600)
                    .frame(width: 26, height: 26)
                    .background(Sourdough.Ramp.sage100)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

                Text("Export My Data")
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)

                Spacer(minLength: Sourdough.Spacing.rowInternals)

                if isExportingData {
                    ProgressView()
                } else {
                    Ph.caretRight.regular
                        .frame(width: 9, height: 12)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExportingData)
    }

    private func exportData() async {
        isExportingData = true
        let urls = await DataExportService.exportAll(
            session: session,
            pantryStore: pantryStore,
            savedRecipesStore: savedRecipesStore,
            userActivityStore: userActivityStore,
            statsStore: statsStore
        )
        isExportingData = false
        if urls.isEmpty {
            showExportError = true
        } else {
            exportedFileURLs = urls
            showExportShare = true
        }
    }

    // MARK: - Sourdough row styling (mirrors AccountSettingsView's profileGroup / settingRow)

    @ViewBuilder
    private func settingsGroup<Rows: View>(
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
    private func settingsRow(
        icon: Image,
        tint: Color,
        ink: Color,
        label: String,
        first: Bool,
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

                Ph.caretRight.regular
                    .frame(width: 9, height: 12)
                    .foregroundStyle(Sourdough.Colors.faintInk)
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
    }

    @ViewBuilder
    private func settingsToggleRow(
        icon: Image,
        tint: Color,
        ink: Color,
        label: String,
        isOn: Binding<Bool>,
        first: Bool
    ) -> some View {
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

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .padding(.vertical, Sourdough.Spacing.rowInternals)
        .overlay(alignment: .top) {
            if !first {
                Rectangle()
                    .fill(Sourdough.Colors.hairline)
                    .frame(height: 1)
                    .padding(.leading, 26 + Sourdough.Spacing.rowInternals * 2)
            }
        }
    }

    /// Row that pushes a `destination` via `NavigationLink`, styled like `settingsRow` (icon tile +
    /// label + chevron, hairline divider when `!first`). `NavigationLink`'s label renders as-is
    /// outside a `List`/`Form`, so no double chevron.
    @ViewBuilder
    private func settingsNavRow<Destination: View>(
        icon: Image,
        tint: Color,
        ink: Color,
        label: String,
        first: Bool,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
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

                Ph.caretRight.regular
                    .frame(width: 9, height: 12)
                    .foregroundStyle(Sourdough.Colors.faintInk)
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
    }

    private var blockedAccountsRow: some View {
        settingsNavRow(icon: Ph.prohibit.regular, tint: Sourdough.Ramp.linen100, ink: Sourdough.Ramp.linen500,
                       label: "Blocked Accounts", first: true) {
            BlockedAccountsView().environmentObject(savedRecipesStore)
        }
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
    }

    /// Light/dark toggle, flanked by sun/moon indicator icons. Bespoke shape (not built from
    /// `settingsToggleRow`) — moved here from `AccountSettingsView`.
    private var themeRow: some View {
        let isDark = session.colorSchemePreference == .dark
        return HStack(spacing: Sourdough.Spacing.rowInternals) {
            Ph.lightbulb.regular
                .frame(width: 13, height: 13)
                .foregroundStyle(Sourdough.Ramp.honey700)
                .frame(width: 26, height: 26)
                .background(Sourdough.Ramp.honey100)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

            Text("Theme")
                .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)

            Spacer(minLength: Sourdough.Spacing.rowInternals)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 13))
                .foregroundStyle(isDark ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)

            Toggle("", isOn: Binding(
                get: { isDark },
                set: { session.colorSchemePreference = $0 ? .dark : .light }
            ))
            .labelsHidden()

            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundStyle(isDark ? Sourdough.Colors.ink : Sourdough.Colors.faintInk)
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .padding(.vertical, Sourdough.Spacing.rowInternals)
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @AppStorage("expiringItemsNotificationsEnabled") private var expiringItemsEnabled = true
    @AppStorage("recipeSuggestionsEnabled") private var recipeSuggestionsEnabled = true
    @State private var notificationsAuthorized = false

    var body: some View {
        Form {
            Section {
                Toggle("Allow Notifications", isOn: Binding(
                    get: { notificationsAuthorized },
                    set: { _ in handleNotificationToggle() }
                ))
            } footer: {
                if !notificationsAuthorized {
                    Text("Turn on notifications for Use Up in the iOS Settings app to receive these reminders.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                }
            }

            Section {
                Toggle("Expiring Items", isOn: $expiringItemsEnabled)
                Toggle("Recipe Suggestions", isOn: $recipeSuggestionsEnabled)
            } header: {
                Text("Reminders")
            } footer: {
                Text("Choose which reminders Use Up sends to your device.")
            }
        }
        .navigationTitle("Notifications")
        .preference(key: HideTabBarKey.self, value: true)
        .task { await refreshNotificationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
        .onChange(of: expiringItemsEnabled) { _, _ in reschedule() }
        .onChange(of: recipeSuggestionsEnabled) { _, newValue in
            if newValue { Task { await requestAuthorizationIfNeeded() } }
            reschedule()
        }
    }

    private func reschedule() {
        Task { await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients) }
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
