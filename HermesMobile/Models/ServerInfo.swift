import Foundation

struct HealthResponse: Decodable {
    let status: String?
    let sessions: Int?
    let activeStreams: Int?
    let uptimeSeconds: Double?
}

struct AuthStatusResponse: Decodable {
    let authEnabled: Bool?
    let loggedIn: Bool?
    /// Finer-grained capabilities newer servers report. All optional so older
    /// servers that omit them decode unchanged. `password_auth_enabled == false`
    /// (and only an explicit false) marks a passkey-only server we can't sign
    /// into yet (#255); a missing value means "unknown" → treat as today.
    let passwordAuthEnabled: Bool?
    let passkeysEnabled: Bool?
    let passwordlessEnabled: Bool?

    init(
        authEnabled: Bool? = nil,
        loggedIn: Bool? = nil,
        passwordAuthEnabled: Bool? = nil,
        passkeysEnabled: Bool? = nil,
        passwordlessEnabled: Bool? = nil
    ) {
        self.authEnabled = authEnabled
        self.loggedIn = loggedIn
        self.passwordAuthEnabled = passwordAuthEnabled
        self.passkeysEnabled = passkeysEnabled
        self.passwordlessEnabled = passwordlessEnabled
    }
}

struct LoginResponse: Decodable {
    let ok: Bool?
    let message: String?
    let error: String?
}

struct UniOpsMobileSessionRequest: Encodable {
    let credential: String
    let deviceId: String?
    let deviceName: String?
}

struct UniOpsMobileSessionResponse: Decodable, Equatable {
    let success: Bool?
    let token: String?
    let refreshToken: String?
    let sessionId: String?
    let expiresIn: Int?
    let refreshExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case refreshToken
        case sessionId
        case expiresIn
        case refreshExpiresAt
    }

    init(
        success: Bool? = nil,
        token: String? = nil,
        refreshToken: String? = nil,
        sessionId: String? = nil,
        expiresIn: Int? = nil,
        refreshExpiresAt: String? = nil
    ) {
        self.success = success
        self.token = token
        self.refreshToken = refreshToken
        self.sessionId = sessionId
        self.expiresIn = expiresIn
        self.refreshExpiresAt = refreshExpiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = container.decodeLossyBoolIfPresent(forKey: .success)
        token = container.decodeLossyStringIfPresent(forKey: .token)
        refreshToken = container.decodeLossyStringIfPresent(forKey: .refreshToken)
        sessionId = container.decodeLossyStringIfPresent(forKey: .sessionId)
        expiresIn = container.decodeLossyIntIfPresent(forKey: .expiresIn)
        refreshExpiresAt = container.decodeLossyStringIfPresent(forKey: .refreshExpiresAt)
    }
}

struct UniOpsMobileRefreshRequest: Encodable {
    let refreshToken: String
}

struct UniOpsMobileRefreshResponse: Decodable, Equatable {
    let success: Bool?
    let token: String?
    let sessionId: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case sessionId
        case expiresIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = container.decodeLossyBoolIfPresent(forKey: .success)
        token = container.decodeLossyStringIfPresent(forKey: .token)
        sessionId = container.decodeLossyStringIfPresent(forKey: .sessionId)
        expiresIn = container.decodeLossyIntIfPresent(forKey: .expiresIn)
    }
}

struct UniOpsMobileSessionsResponse: Decodable, Equatable {
    let success: Bool?
    let sessions: [UniOpsMobileSession]

    enum CodingKeys: String, CodingKey {
        case success
        case sessions
    }

    init(success: Bool? = nil, sessions: [UniOpsMobileSession] = []) {
        self.success = success
        self.sessions = sessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = container.decodeLossyBoolIfPresent(forKey: .success)
        sessions = (try? container.decodeIfPresent([UniOpsMobileSession].self, forKey: .sessions)) ?? []
    }
}

struct UniOpsMobileSession: Decodable, Equatable, Identifiable {
    let id: String
    let channel: String?
    let tokenClass: String?
    let deviceName: String?
    let deviceId: String?
    let createdAt: String?
    let lastSeenAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case tokenClass
        case deviceName
        case deviceId
        case createdAt
        case lastSeenAt
        case expiresAt
    }

    init(
        id: String,
        channel: String? = nil,
        tokenClass: String? = nil,
        deviceName: String? = nil,
        deviceId: String? = nil,
        createdAt: String? = nil,
        lastSeenAt: String? = nil,
        expiresAt: String? = nil
    ) {
        self.id = id
        self.channel = channel
        self.tokenClass = tokenClass
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.expiresAt = expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyStringIfPresent(forKey: .id) ?? ""
        channel = container.decodeLossyStringIfPresent(forKey: .channel)
        tokenClass = container.decodeLossyStringIfPresent(forKey: .tokenClass)
        deviceName = container.decodeLossyStringIfPresent(forKey: .deviceName)
        deviceId = container.decodeLossyStringIfPresent(forKey: .deviceId)
        createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
        lastSeenAt = container.decodeLossyStringIfPresent(forKey: .lastSeenAt)
        expiresAt = container.decodeLossyStringIfPresent(forKey: .expiresAt)
    }
}

struct UniOpsMobilePushTokenRequest: Encodable {
    let token: String
    let deviceId: String?
    let platform: String
}

struct UniOpsMobilePushTokenResponse: Decodable, Equatable {
    let success: Bool?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case success
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = container.decodeLossyBoolIfPresent(forKey: .success)
        id = container.decodeLossyStringIfPresent(forKey: .id)
    }
}

struct UniOpsAPIResponse<Payload: Decodable>: Decodable {
    let ok: Bool?
    let data: Payload?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case data
        case message
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.decodeLossyBoolIfPresent(forKey: .ok)
        data = try? container.decodeIfPresent(Payload.self, forKey: .data)
        message = container.decodeLossyStringIfPresent(forKey: .message)
        error = container.decodeLossyStringIfPresent(forKey: .error)
    }
}

struct UniOpsDecisionResponse: Decodable, Equatable {
    let ok: Bool?
    let success: Bool?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case success
        case message
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.decodeLossyBoolIfPresent(forKey: .ok)
        success = container.decodeLossyBoolIfPresent(forKey: .success)
        message = container.decodeLossyStringIfPresent(forKey: .message)
        error = container.decodeLossyStringIfPresent(forKey: .error)
    }
}

/// Unified Approvals Command Center (`uniops#226`) — one shape covering every
/// source (`openclaw` incl. GitHub escrow, `agent_runtime`, `autopilot`,
/// `supplier_ops`). Supersedes the old per-source Runtime/NightShift/
/// OpenClaw/Autopilot/Escrow payload zoo. NightShift is intentionally not a
/// source here.
struct UniOpsApprovalsPayload: Decodable, Equatable {
    let items: [PendingApprovalItem]
    let counts: UniOpsApprovalCounts
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case items
        case counts
        case generatedAt
    }

    init(
        items: [PendingApprovalItem] = [],
        counts: UniOpsApprovalCounts = UniOpsApprovalCounts(),
        generatedAt: String? = nil
    ) {
        self.items = items
        self.counts = counts
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decodeIfPresent([PendingApprovalItem].self, forKey: .items)) ?? []
        counts = (try? container.decodeIfPresent(UniOpsApprovalCounts.self, forKey: .counts)) ?? UniOpsApprovalCounts()
        generatedAt = container.decodeLossyStringIfPresent(forKey: .generatedAt)
    }
}

struct UniOpsApprovalCounts: Decodable, Equatable {
    let total: Int
    let bySource: [String: Int]

    enum CodingKeys: String, CodingKey {
        case total
        case bySource
    }

    init(total: Int = 0, bySource: [String: Int] = [:]) {
        self.total = total
        self.bySource = bySource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.decodeLossyIntIfPresent(forKey: .total) ?? 0
        bySource = (try? container.decodeIfPresent([String: Int].self, forKey: .bySource)) ?? [:]
    }
}

/// `source: "openclaw"` items with a title prefixed `GitHub · ...` are escrow
/// decisions — approve/deny still routes through `decide`, same as any other
/// OpenClaw item. There is no separate escrow case to branch on client-side.
struct PendingApprovalItem: Decodable, Equatable, Identifiable {
    let id: String
    let source: String
    let title: String?
    let description: String?
    let riskTier: String?
    let requestedBy: String?
    let requestedAt: String?
    let stepUp: Bool
    let href: String?
    let decide: UniOpsApprovalDecideActions

    var displayTitle: String { title ?? id }
    var displaySubtitle: String { description ?? source }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case title
        case description
        case riskTier
        case requestedBy
        case requestedAt
        case stepUp
        case href
        case decide
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyStringIfPresent(forKey: .id) ?? ""
        source = container.decodeLossyStringIfPresent(forKey: .source) ?? "openclaw"
        title = container.decodeLossyStringIfPresent(forKey: .title)
        description = container.decodeLossyStringIfPresent(forKey: .description)
        riskTier = container.decodeLossyStringIfPresent(forKey: .riskTier)
        requestedBy = container.decodeLossyStringIfPresent(forKey: .requestedBy)
        requestedAt = container.decodeLossyStringIfPresent(forKey: .requestedAt)
        stepUp = (try? container.decodeIfPresent(Bool.self, forKey: .stepUp)) ?? false
        href = container.decodeLossyStringIfPresent(forKey: .href)
        decide = (try? container.decodeIfPresent(UniOpsApprovalDecideActions.self, forKey: .decide))
            ?? UniOpsApprovalDecideActions()
    }
}

/// Carries the exact `{url, body}` (+ optional headers/reasonField) the app
/// must POST verbatim on approve/deny — the client never hand-constructs a
/// per-source request shape.
struct UniOpsApprovalDecideActions: Decodable, Equatable {
    let approve: UniOpsApprovalDecideAction?
    let deny: UniOpsApprovalDecideAction?
    let headers: [String: String]
    let reasonField: String?

    enum CodingKeys: String, CodingKey {
        case approve
        case deny
        case headers
        case reasonField
    }

    init(
        approve: UniOpsApprovalDecideAction? = nil,
        deny: UniOpsApprovalDecideAction? = nil,
        headers: [String: String] = [:],
        reasonField: String? = nil
    ) {
        self.approve = approve
        self.deny = deny
        self.headers = headers
        self.reasonField = reasonField
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        approve = try? container.decodeIfPresent(UniOpsApprovalDecideAction.self, forKey: .approve)
        deny = try? container.decodeIfPresent(UniOpsApprovalDecideAction.self, forKey: .deny)
        headers = (try? container.decodeIfPresent([String: String].self, forKey: .headers)) ?? [:]
        reasonField = container.decodeLossyStringIfPresent(forKey: .reasonField)
    }
}

struct UniOpsApprovalDecideAction: Decodable, Equatable {
    let url: String
    let body: JSONValue?

    enum CodingKeys: String, CodingKey {
        case url
        case body
    }

    init(url: String, body: JSONValue? = nil) {
        self.url = url
        self.body = body
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.decodeLossyStringIfPresent(forKey: .url) ?? ""
        body = try? container.decodeIfPresent(JSONValue.self, forKey: .body)
    }
}

extension JSONValue {
    /// Merges an owner-supplied note into a decide-action body under the
    /// server-specified `reasonField` key (`"reason"` / `"decisionNote"` /
    /// nil — nil means this source doesn't accept a note). Non-destructive:
    /// starts from `self` if it's already an object, otherwise an empty one.
    func mergingReason(_ reason: String?, field: String?) -> JSONValue {
        guard let field, let reason, !reason.isEmpty else { return self }
        var dict: [String: JSONValue]
        if case let .object(existing) = self {
            dict = existing
        } else {
            dict = [:]
        }
        dict[field] = .string(reason)
        return .object(dict)
    }
}

struct UniOpsApprovalInboxSnapshot: Equatable {
    let sessions: [UniOpsMobileSession]
    let items: [PendingApprovalItem]
    let counts: UniOpsApprovalCounts

    init(
        sessions: [UniOpsMobileSession] = [],
        items: [PendingApprovalItem] = [],
        counts: UniOpsApprovalCounts = UniOpsApprovalCounts()
    ) {
        self.sessions = sessions
        self.items = items
        self.counts = counts
    }
}
