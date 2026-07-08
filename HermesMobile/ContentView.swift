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
    @State private var approvals: [PendingApprovalItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var pendingDecision: UniOpsPendingDecision?

    private var layoutDirection: LayoutDirection {
        UniOpsLocalePolicy.layoutDirection(for: locale)
    }

    private var currentSession: UniOpsMobileSession? {
        guard let id = authManager.currentUniOpsSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    private var approvalCount: Int {
        approvals.count
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
                    dashboardRow(title: String(localized: "Waiting Approvals"), value: "\(approvalCount)")
                } header: {
                    Text("Dashboard Summary")
                }

                Section {
                    if approvalCount == 0 {
                        Text("No approvals are waiting.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(approvals.prefix(20))) { item in
                        approvalItemRow(item)
                    }
                } header: {
                    Text("Approvals")
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

                if let actionMessage {
                    Section {
                        Text(actionMessage)
                            .foregroundStyle(.secondary)
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
            .confirmationDialog(
                pendingDecision?.confirmationTitle ?? String(localized: "Confirm Owner Action"),
                isPresented: Binding(
                    get: { pendingDecision != nil },
                    set: { isPresented in
                        if !isPresented { pendingDecision = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDecision
            ) { decision in
                Button(decision.actionLabel, role: decision.buttonRole) {
                    Task { await perform(decision) }
                }
                Button("Cancel", role: .cancel) {
                    pendingDecision = nil
                }
            } message: { decision in
                Text(decision.confirmationMessage)
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

    private func approvalItemRow(_ item: PendingApprovalItem) -> some View {
        approvalRow(
            systemImage: sourceSystemImage(item.source),
            title: item.displayTitle,
            subtitle: item.description ?? sourceLabel(item.source),
            badges: [sourceLabel(item.source), item.riskTier].compactMap { $0 },
            approve: .decide(item: item, approved: true),
            canReject: item.decide.deny != nil,
            reject: .decide(item: item, approved: false)
        )
    }

    /// `source` values come from the unified Approvals Command Center
    /// (`openclaw` — includes GitHub escrow, `agent_runtime`, `autopilot`,
    /// `supplier_ops`). NightShift is not a source here.
    private func sourceSystemImage(_ source: String) -> String {
        switch source {
        case "openclaw":
            return "person.crop.circle.badge.checkmark"
        case "agent_runtime":
            return "cpu"
        case "autopilot":
            return "gearshape.2"
        case "supplier_ops":
            return "building.2"
        default:
            return "checkmark.seal"
        }
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "openclaw":
            return String(localized: "OpenClaw")
        case "agent_runtime":
            return String(localized: "Agent Runtime")
        case "autopilot":
            return String(localized: "Autopilot")
        case "supplier_ops":
            return String(localized: "Supplier Ops")
        default:
            return source
        }
    }

    private func approvalRow(
        systemImage: String,
        title: String,
        subtitle: String,
        badges: [String],
        approve: UniOpsPendingDecision,
        canReject: Bool,
        reject: UniOpsPendingDecision
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(verbatim: title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.blue)
            }

            Text(verbatim: subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !badges.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        ForEach(badges, id: \.self) { badge in
                            Text(verbatim: badge)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    VStack(alignment: .leading) {
                        ForEach(badges, id: \.self) { badge in
                            Text(verbatim: badge)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            HStack {
                if canReject {
                    Button(role: .destructive) {
                        pendingDecision = reject
                    } label: {
                        Label("Reject", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    pendingDecision = approve
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await authManager.loadUniOpsApprovalInbox()
            sessions = snapshot.sessions
            approvals = snapshot.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func perform(_ decision: UniOpsPendingDecision) async {
        isLoading = true
        errorMessage = nil
        actionMessage = nil
        pendingDecision = nil
        defer { isLoading = false }

        do {
            switch decision {
            case let .decide(item, approved):
                try await authManager.decideUniOpsApproval(item, approved: approved)
            }
            actionMessage = String(localized: "Decision Sent")
            await load()
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

enum UniOpsPendingDecision: Identifiable, Equatable {
    case decide(item: PendingApprovalItem, approved: Bool)

    var id: String {
        switch self {
        case let .decide(item, approved):
            return "\(item.id)-\(approved)"
        }
    }

    /// Fed to `UniOpsOwnerActionPolicy.requiresFounderConfirmation` — mirrors
    /// the backend's owner-confirmation triggers over the item's full text.
    var subject: String {
        switch self {
        case let .decide(item, _):
            return [item.displayTitle, item.description].compactMap { $0 }.joined(separator: " ")
        }
    }

    var actionLabel: String {
        switch self {
        case let .decide(_, approved):
            return approved ? String(localized: "Approve") : String(localized: "Reject")
        }
    }

    var buttonRole: ButtonRole? {
        actionLabel == String(localized: "Reject") ? .destructive : nil
    }

    var confirmationTitle: String {
        UniOpsOwnerActionPolicy.requiresFounderConfirmation(text: subject)
            ? String(localized: "Founder Confirmation Required")
            : String(localized: "Confirm Owner Action")
    }

    var confirmationMessage: String {
        UniOpsOwnerActionPolicy.requiresFounderConfirmation(text: subject)
            ? String(localized: "This action mentions protected operations. Confirm from trusted evidence before deciding.")
            : String(localized: "Confirm this approval decision.")
    }
}

enum UniOpsOwnerActionPolicy {
    private static let protectedTerms = [
        "delete",
        "deploy",
        "production",
        "payment",
        "payroll",
        "secret",
        "credential",
        "dns",
        "iam",
        "firewall",
        "customer",
        "legal",
        "refund"
    ]

    static func requiresFounderConfirmation(text: String) -> Bool {
        let lowered = text.lowercased()
        return protectedTerms.contains { lowered.contains($0) }
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
