import GoogleSignIn
import SwiftUI
import UserNotifications

struct ContentView: View {
    @Bindable var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ResponseCompletionNotifications.isEnabledKey) private var isResponseCompletionNotificationsEnabled = false
    @State private var pendingSharedImport: SharedImport?
    @State private var pendingDeepLinkedSessionID: String?
    @State private var pendingNewChatRequest: NewChatRequest?
    @State private var didCheckInitialPendingShare = false
    @State private var intentRouter = AppIntentRouter.shared

    var body: some View {
        content
            .onOpenURL(perform: handleOpenURL)
            .onReceive(NotificationCenter.default.publisher(for: .uniOpsAPNsTokenDidChange)) { notification in
                guard let token = notification.object as? String else { return }
                Task { await authManager.registerUniOpsPushToken(token) }
            }
            .task {
                guard !didCheckInitialPendingShare else { return }
                didCheckInitialPendingShare = true
                importPendingSharedDraftIfAvailable()
                // Cold launch: an App Intent may have queued a deep link before this
                // view appeared (e.g. Action button "New Chat"). Drain it now (#337).
                drainPendingIntentDeepLink()
            }
            .onChange(of: intentRouter.pendingDeepLink) {
                // Warm launch: the intent set the deep link after the view appeared.
                drainPendingIntentDeepLink()
            }
            .task {
                // #246: on cold launch, end any Live Activity left "running" by a
                // run that finished while the app was terminated. #248: this is also
                // the one pass allowed to fire a recent run's "response complete"
                // notification, since a relaunch means it finished while not active.
                await reconcileOrphanedLiveActivities(notifiesOnCompletion: true)
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                importPendingSharedDraftIfAvailable()
                // #248: the foreground pass stays silent — the in-session completion
                // paths own notifications while the app is alive.
                Task { await reconcileOrphanedLiveActivities(notifiesOnCompletion: false) }
            }
    }

    private func reconcileOrphanedLiveActivities(notifiesOnCompletion: Bool) async {
        guard case let .loggedIn(server) = authManager.state else { return }
        await LiveActivityReconciler.reconcileOrphanedActivities(
            server: server,
            notifiesOnCompletion: notifiesOnCompletion,
            preferenceEnabled: isResponseCompletionNotificationsEnabled
        )
    }

    @ViewBuilder
    private var content: some View {
        switch authManager.state {
        case .unconfigured:
            OnboardingView(authManager: authManager)
        case .loggedOut(let server):
            OnboardingView(authManager: authManager, savedServer: server)
        case .loggedIn(let server):
            SessionListView(
                authManager: authManager,
                server: server,
                pendingSharedImport: $pendingSharedImport,
                pendingDeepLinkedSessionID: $pendingDeepLinkedSessionID,
                requestedNewChat: $pendingNewChatRequest
            )
            // Switching the active server keeps us in `.loggedIn`, so without a
            // per-server identity SwiftUI would reuse the same SessionListView (and
            // its server-bound view model), leaving stale sessions/chat on screen.
            // Keying on the server tears the whole stack down and rebuilds it
            // against the newly active server (#17).
            .id(server)
        case .uniOpsLocked(let server):
            UniOpsLockedView(authManager: authManager, server: server)
                .id(server)
        case .uniOpsSignedIn(let server):
            UniOpsDashboardView(authManager: authManager, server: server)
                .id(server)
        }
    }

    private func handleOpenURL(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        // A fresh request each time (new `id`) so a repeat invocation re-triggers navigation
        // even if the previous one's value still lingers downstream. The voice variant carries
        // `autoStartsVoiceInput` so the composer begins dictation once it appears (#338).
        if HermesDeepLink.isNewChatVoiceURL(url) {
            pendingNewChatRequest = NewChatRequest(autoStartsVoiceInput: true)
            return
        }

        // The profile variant carries the chosen profile name, so the composer creates the
        // session pinned to it (#339). A malformed link with no profile falls back to a
        // plain new chat (server's active profile) rather than failing.
        if HermesDeepLink.isNewChatInProfileURL(url) {
            pendingNewChatRequest = NewChatRequest(
                profileName: HermesDeepLink.profileName(fromNewChatInProfile: url)
            )
            return
        }

        if HermesDeepLink.isNewChatURL(url) {
            pendingNewChatRequest = NewChatRequest(autoStartsVoiceInput: false)
            return
        }

        if let sessionID = HermesDeepLink.sessionID(from: url) {
            pendingDeepLinkedSessionID = sessionID
            return
        }

        guard HermesShareDraft.isShareOpenURL(url) else {
            return
        }

        importPendingSharedDraftIfAvailable()
    }

    /// Routes a deep link queued by an App Intent through the same `handleOpenURL` parser
    /// used for external URLs, then clears it so it routes exactly once (#337).
    private func drainPendingIntentDeepLink() {
        guard let url = intentRouter.pendingDeepLink else { return }
        intentRouter.pendingDeepLink = nil
        handleOpenURL(url)
    }

    private func importPendingSharedDraftIfAvailable() {
        guard let directory = HermesShareDraft.containerURL() else {
            return
        }

        do {
            if let sharedImport = try HermesShareDraft.loadPendingImport(from: directory) {
                pendingSharedImport = sharedImport
            }
        } catch {
            pendingSharedImport = nil
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
}

private struct UniOpsLockedView: View {
    @Bindable var authManager: AuthManager
    let server: URL

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "faceid")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("UniOps Locked")
                    .font(.title2.weight(.bold))
                Text(verbatim: server.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message = authManager.lastErrorMessage {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await authManager.unlockUniOpsWithBiometrics() }
            } label: {
                Label("Unlock with Face ID", systemImage: "lock.open")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Sign Out", role: .destructive) {
                Task { await authManager.signOut() }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .task {
            await authManager.unlockUniOpsWithBiometrics()
        }
    }
}

private struct UniOpsDashboardView: View {
    @Bindable var authManager: AuthManager
    let server: URL

    @Environment(\.locale) private var locale
    @State private var sessions: [UniOpsMobileSession] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var layoutDirection: LayoutDirection {
        UniOpsLocalePolicy.layoutDirection(for: locale)
    }

    private var currentSession: UniOpsMobileSession? {
        guard let id = authManager.currentUniOpsSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dashboardRow(title: String(localized: "Server"), value: server.absoluteString)
                    dashboardRow(title: String(localized: "Session"), value: authManager.currentUniOpsSessionID ?? String(localized: "Unknown"))
                    dashboardRow(title: String(localized: "Active Sessions"), value: "\(sessions.count)")
                    dashboardRow(title: String(localized: "Channel"), value: currentSession?.channel ?? String(localized: "Mobile owner console"))
                    dashboardRow(title: String(localized: "Token Class"), value: currentSession?.tokenClass ?? String(localized: "Founder"))
                } header: {
                    Text("Dashboard Summary")
                }

                Section {
                    Button {
                        requestPushToken()
                    } label: {
                        Label("Register This iPhone for Push", systemImage: "bell.badge")
                    }

                    Button {
                        Task { await load() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(verbatim: errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("UniOps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out", role: .destructive) {
                        Task { await authManager.signOut() }
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await load()
                requestPushToken()
            }
            .refreshable {
                await load()
            }
        }
        .environment(\.layoutDirection, layoutDirection)
    }

    private func dashboardRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            sessions = try await authManager.loadUniOpsSessions().sessions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestPushToken() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

public enum UniOpsLocalePolicy {
    public static func layoutDirection(for locale: Locale) -> LayoutDirection {
        locale.language.languageCode?.identifier == "ar" ? .rightToLeft : .leftToRight
    }
}

extension Notification.Name {
    static let uniOpsAPNsTokenDidChange = Notification.Name("uniOpsAPNsTokenDidChange")
}
