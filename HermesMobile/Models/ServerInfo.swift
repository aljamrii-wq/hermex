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

struct UniOpsDecisionPayload: Decodable, Equatable {}

struct UniOpsRuntimeApprovalsPayload: Decodable, Equatable {
    let approvals: [UniOpsRuntimeApproval]

    enum CodingKeys: String, CodingKey {
        case approvals
    }

    init(approvals: [UniOpsRuntimeApproval] = []) {
        self.approvals = approvals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        approvals = (try? container.decodeIfPresent([UniOpsRuntimeApproval].self, forKey: .approvals)) ?? []
    }
}

struct UniOpsRuntimeApproval: Decodable, Equatable, Identifiable {
    let id: String
    let tenantId: String?
    let taskId: String?
    let category: String?
    let reason: String?
    let status: String?
    let requestedBy: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId
        case taskId
        case category
        case reason
        case status
        case requestedBy
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        tenantId: String? = nil,
        taskId: String? = nil,
        category: String? = nil,
        reason: String? = nil,
        status: String? = nil,
        requestedBy: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.taskId = taskId
        self.category = category
        self.reason = reason
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyStringIfPresent(forKey: .id) ?? ""
        tenantId = container.decodeLossyStringIfPresent(forKey: .tenantId)
        taskId = container.decodeLossyStringIfPresent(forKey: .taskId)
        category = container.decodeLossyStringIfPresent(forKey: .category)
        reason = container.decodeLossyStringIfPresent(forKey: .reason)
        status = container.decodeLossyStringIfPresent(forKey: .status)
        requestedBy = container.decodeLossyStringIfPresent(forKey: .requestedBy)
        createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
        updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
    }
}

struct UniOpsRuntimeApprovalDecisionRequest: Encodable {
    let approved: Bool
    let decisionNote: String?
}

struct UniOpsRuntimeApprovalDecisionPayload: Decodable, Equatable {
    let approval: UniOpsRuntimeApproval?

    enum CodingKeys: String, CodingKey {
        case approval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        approval = try? container.decodeIfPresent(UniOpsRuntimeApproval.self, forKey: .approval)
    }
}

struct UniOpsNightShiftImprovementsPayload: Decodable, Equatable {
    let result: UniOpsNightShiftImprovementList?

    var proposals: [UniOpsNightShiftImprovement] {
        result?.proposals ?? []
    }

    enum CodingKeys: String, CodingKey {
        case result
    }

    init(result: UniOpsNightShiftImprovementList? = nil) {
        self.result = result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try? container.decodeIfPresent(UniOpsNightShiftImprovementList.self, forKey: .result)
    }
}

struct UniOpsNightShiftImprovementList: Decodable, Equatable {
    let botId: String?
    let count: Int?
    let proposals: [UniOpsNightShiftImprovement]

    enum CodingKeys: String, CodingKey {
        case botId
        case count
        case proposals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        botId = container.decodeLossyStringIfPresent(forKey: .botId)
        count = container.decodeLossyIntIfPresent(forKey: .count)
        proposals = (try? container.decodeIfPresent([UniOpsNightShiftImprovement].self, forKey: .proposals)) ?? []
    }
}

struct UniOpsNightShiftImprovement: Decodable, Equatable, Identifiable {
    let proposalKey: String
    let botId: String?
    let kind: String?
    let title: String?
    let summary: String?
    let status: String?
    let verificationStatus: String?
    let details: Details?

    var id: String { proposalKey }
    var displaySummary: String? { summary ?? details?.summary ?? details?.suggestedAction }
    var risk: String? { details?.risk }
    var projectScope: String? { details?.projectScope }

    struct Details: Decodable, Equatable {
        let projectScope: String?
        let risk: String?
        let summary: String?
        let suggestedAction: String?

        enum CodingKeys: String, CodingKey {
            case projectScope
            case risk
            case summary
            case suggestedAction
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            projectScope = container.decodeLossyStringIfPresent(forKey: .projectScope)
            risk = container.decodeLossyStringIfPresent(forKey: .risk)
            summary = container.decodeLossyStringIfPresent(forKey: .summary)
            suggestedAction = container.decodeLossyStringIfPresent(forKey: .suggestedAction)
        }
    }

    enum CodingKeys: String, CodingKey {
        case proposalKey
        case botId
        case kind
        case title
        case summary
        case status
        case verificationStatus
        case details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        proposalKey = container.decodeLossyStringIfPresent(forKey: .proposalKey) ?? ""
        botId = container.decodeLossyStringIfPresent(forKey: .botId)
        kind = container.decodeLossyStringIfPresent(forKey: .kind)
        title = container.decodeLossyStringIfPresent(forKey: .title)
        summary = container.decodeLossyStringIfPresent(forKey: .summary)
        status = container.decodeLossyStringIfPresent(forKey: .status)
        verificationStatus = container.decodeLossyStringIfPresent(forKey: .verificationStatus)
        details = try? container.decodeIfPresent(Details.self, forKey: .details)
    }
}

struct UniOpsNightShiftImprovementDecisionRequest: Encodable {
    let proposalKey: String
    let decision: String
    let botId: String?
    let feedbackNote: String?
}

struct UniOpsNightShiftImprovementDecisionPayload: Decodable, Equatable {
    let result: UniOpsNightShiftImprovementDecisionResult?

    enum CodingKeys: String, CodingKey {
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try? container.decodeIfPresent(UniOpsNightShiftImprovementDecisionResult.self, forKey: .result)
    }
}

struct UniOpsNightShiftImprovementDecisionResult: Decodable, Equatable {
    let updated: UniOpsNightShiftImprovement?

    enum CodingKeys: String, CodingKey {
        case updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updated = try? container.decodeIfPresent(UniOpsNightShiftImprovement.self, forKey: .updated)
    }
}

struct UniOpsNightShiftSkillsPayload: Decodable, Equatable {
    let result: UniOpsNightShiftSkillList?

    var cards: [UniOpsNightShiftSkillCard] {
        result?.cards ?? []
    }

    enum CodingKeys: String, CodingKey {
        case result
    }

    init(result: UniOpsNightShiftSkillList? = nil) {
        self.result = result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try? container.decodeIfPresent(UniOpsNightShiftSkillList.self, forKey: .result)
    }
}

struct UniOpsNightShiftSkillList: Decodable, Equatable {
    let botId: String?
    let count: Int?
    let cards: [UniOpsNightShiftSkillCard]

    enum CodingKeys: String, CodingKey {
        case botId
        case count
        case cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        botId = container.decodeLossyStringIfPresent(forKey: .botId)
        count = container.decodeLossyIntIfPresent(forKey: .count)
        cards = (try? container.decodeIfPresent([UniOpsNightShiftSkillCard].self, forKey: .cards)) ?? []
    }
}

struct UniOpsNightShiftSkillCard: Decodable, Equatable, Identifiable {
    let skillKey: String
    let botId: String?
    let scope: String?
    let title: String?
    let action: String?
    let rationale: String?
    let status: String?
    let updatedAt: String?

    var id: String { skillKey }

    enum CodingKeys: String, CodingKey {
        case skillKey
        case botId
        case scope
        case title
        case action
        case rationale
        case status
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillKey = container.decodeLossyStringIfPresent(forKey: .skillKey) ?? ""
        botId = container.decodeLossyStringIfPresent(forKey: .botId)
        scope = container.decodeLossyStringIfPresent(forKey: .scope)
        title = container.decodeLossyStringIfPresent(forKey: .title)
        action = container.decodeLossyStringIfPresent(forKey: .action)
        rationale = container.decodeLossyStringIfPresent(forKey: .rationale)
        status = container.decodeLossyStringIfPresent(forKey: .status)
        updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
    }
}

struct UniOpsNightShiftSkillDecisionRequest: Encodable {
    let skillKey: String
    let action: String
    let botId: String?
}

struct UniOpsNightShiftSkillDecisionPayload: Decodable, Equatable {
    let result: UniOpsNightShiftSkillDecisionResult?

    enum CodingKeys: String, CodingKey {
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try? container.decodeIfPresent(UniOpsNightShiftSkillDecisionResult.self, forKey: .result)
    }
}

struct UniOpsNightShiftSkillDecisionResult: Decodable, Equatable {
    let updated: UniOpsNightShiftSkillCard?

    enum CodingKeys: String, CodingKey {
        case updated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updated = try? container.decodeIfPresent(UniOpsNightShiftSkillCard.self, forKey: .updated)
    }
}

struct UniOpsReasonRequest: Encodable {
    let reason: String?
}

struct UniOpsAutopilotActionDecisionRequest: Encodable {
    let approved: Bool
}

struct UniOpsApprovalInboxSnapshot: Equatable {
    let sessions: [UniOpsMobileSession]
    let runtimeApprovals: [UniOpsRuntimeApproval]
    let improvementProposals: [UniOpsNightShiftImprovement]
    let skillCards: [UniOpsNightShiftSkillCard]

    init(
        sessions: [UniOpsMobileSession] = [],
        runtimeApprovals: [UniOpsRuntimeApproval] = [],
        improvementProposals: [UniOpsNightShiftImprovement] = [],
        skillCards: [UniOpsNightShiftSkillCard] = []
    ) {
        self.sessions = sessions
        self.runtimeApprovals = runtimeApprovals
        self.improvementProposals = improvementProposals
        self.skillCards = skillCards
    }
}
