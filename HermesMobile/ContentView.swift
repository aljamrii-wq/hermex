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
    @State private var tenantID = "aljamri"
    @State private var runtimeApprovals: [UniOpsRuntimeApproval] = []
    @State private var improvementProposals: [UniOpsNightShiftImprovement] = []
    @State private var skillCards: [UniOpsNightShiftSkillCard] = []
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
        runtimeApprovals.count + improvementProposals.count + skillCards.count
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
                    TextField("Tenant", text: $tenantID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await load() }
                        }
                } header: {
                    Text("Runtime Tenant")
                }

                Section {
                    if approvalCount == 0 {
                        Text("No approvals are waiting.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(runtimeApprovals.prefix(5))) { approval in
                        runtimeApprovalRow(approval)
                    }

                    ForEach(Array(improvementProposals.prefix(5))) { proposal in
                        improvementProposalRow(proposal)
                    }

                    ForEach(Array(skillCards.prefix(5))) { card in
                        skillCardRow(card)
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

    private func runtimeApprovalRow(_ approval: UniOpsRuntimeApproval) -> some View {
        approvalRow(
            systemImage: "person.crop.circle.badge.checkmark",
            title: approval.reason ?? approval.category ?? approval.id,
            subtitle: approval.taskId ?? approval.status ?? String(localized: "Runtime approval"),
            badges: [approval.category, approval.status].compactMap { $0 },
            approve: .runtime(id: approval.id, subject: approval.reason ?? approval.id, approved: true),
            reject: .runtime(id: approval.id, subject: approval.reason ?? approval.id, approved: false)
        )
    }

    private func improvementProposalRow(_ proposal: UniOpsNightShiftImprovement) -> some View {
        approvalRow(
            systemImage: "moon.stars",
            title: proposal.title ?? proposal.proposalKey,
            subtitle: proposal.displaySummary ?? proposal.kind ?? String(localized: "NightShift improvement"),
            badges: [proposal.risk, proposal.projectScope, proposal.status].compactMap { $0 },
            approve: .improvement(
                proposalKey: proposal.proposalKey,
                botId: proposal.botId,
                subject: proposal.title ?? proposal.proposalKey,
                decision: "approved"
            ),
            reject: .improvement(
                proposalKey: proposal.proposalKey,
                botId: proposal.botId,
                subject: proposal.title ?? proposal.proposalKey,
                decision: "rejected"
            )
        )
    }

    private func skillCardRow(_ card: UniOpsNightShiftSkillCard) -> some View {
        approvalRow(
            systemImage: "sparkles",
            title: card.title ?? card.skillKey,
            subtitle: card.rationale ?? card.action ?? String(localized: "NightShift skill card"),
            badges: [card.scope, card.status].compactMap { $0 },
            approve: .skill(
                skillKey: card.skillKey,
                botId: card.botId,
                subject: card.title ?? card.skillKey,
                action: "approve"
            ),
            reject: .skill(
                skillKey: card.skillKey,
                botId: card.botId,
                subject: card.title ?? card.skillKey,
                action: "reject"
            )
        )
    }

    private func approvalRow(
        systemImage: String,
        title: String,
        subtitle: String,
        badges: [String],
        approve: UniOpsPendingDecision,
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
                Button(role: .destructive) {
                    pendingDecision = reject
                } label: {
                    Label("Reject", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)

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
            let snapshot = try await authManager.loadUniOpsApprovalInbox(tenantID: tenantID)
            sessions = snapshot.sessions
            runtimeApprovals = snapshot.runtimeApprovals
            improvementProposals = snapshot.improvementProposals
            skillCards = snapshot.skillCards
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
            case let .runtime(id, _, approved):
                try await authManager.decideUniOpsRuntimeApproval(
                    id: id,
                    tenantID: tenantID,
                    approved: approved
                )
            case let .improvement(proposalKey, botId, _, decision):
                try await authManager.decideUniOpsNightShiftImprovement(
                    proposalKey: proposalKey,
                    decision: decision,
                    botId: botId
                )
            case let .skill(skillKey, botId, _, action):
                try await authManager.decideUniOpsNightShiftSkill(
                    skillKey: skillKey,
                    action: action,
                    botId: botId
                )
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
    case runtime(id: String, subject: String, approved: Bool)
    case improvement(proposalKey: String, botId: String?, subject: String, decision: String)
    case skill(skillKey: String, botId: String?, subject: String, action: String)

    var id: String {
        switch self {
        case let .runtime(id, _, approved):
            return "runtime-\(id)-\(approved)"
        case let .improvement(proposalKey, _, _, decision):
            return "improvement-\(proposalKey)-\(decision)"
        case let .skill(skillKey, _, _, action):
            return "skill-\(skillKey)-\(action)"
        }
    }

    var subject: String {
        switch self {
        case let .runtime(_, subject, _),
            let .improvement(_, _, subject, _),
            let .skill(_, _, subject, _):
            return subject
        }
    }

    var actionLabel: String {
        switch self {
        case let .runtime(_, _, approved):
            return approved ? String(localized: "Approve") : String(localized: "Reject")
        case let .improvement(_, _, _, decision):
            return decision == "approved" ? String(localized: "Approve") : String(localized: "Reject")
        case let .skill(_, _, _, action):
            return action == "approve" ? String(localized: "Approve") : String(localized: "Reject")
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
