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
