import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    nonisolated static let emptyPasswordMessage = String(localized: "Enter the server password.")

    enum AuthMode: String, CaseIterable, Identifiable {
        case hermex
        case uniOps

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hermex: return String(localized: "Hermex")
            case .uniOps: return String(localized: "UniOps")
            }
        }
    }

    var authMode: AuthMode = .hermex
    var serverURLString = ""
    var password = ""
    var customHeaders: [CustomHeader] = []
    var authStatus: AuthStatusResponse?
    var connectionMessage: String?
    var errorMessage: String?
    var isWorking = false

    init(
        savedServer: URL? = nil,
        savedHeaders: [CustomHeader] = [],
        initialErrorMessage: String? = nil
    ) {
        if let savedServer {
            serverURLString = savedServer.absoluteString
        }
        customHeaders = savedHeaders
        errorMessage = initialErrorMessage
    }

    var isPasswordRequired: Bool {
        guard authMode == .hermex else { return false }
        // No auth → no password. Passkey-only (auth on, password auth explicitly
        // off) → hide the password field; connect() surfaces the unsupported
        // message instead. Unknown (nil) keeps today's "show the field" default.
        guard authStatus?.authEnabled != false else { return false }
        return authStatus?.passwordAuthEnabled != false
    }

    func testConnection(authManager: AuthManager) async {
        guard authMode == .hermex else {
            connectionMessage = nil
            errorMessage = String(localized: "Use Google Sign-In to verify UniOps.")
            return
        }

        errorMessage = nil
        connectionMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let status = try await authManager.testConnection(
                serverURLString: serverURLString,
                customHeaders: customHeaders
            )
            authStatus = status
            if status.authEnabled == true, status.passwordAuthEnabled == false {
                errorMessage = AuthManager.passkeyOnlyMessage
            } else {
                connectionMessage = status.authEnabled == true
                    ? String(localized: "Connection ok. Password required.")
                    : String(localized: "Connection ok. Password not required.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(authManager: AuthManager) async {
        errorMessage = nil
        connectionMessage = nil

        guard authMode == .hermex else {
            await connectUniOps(authManager: authManager)
            return
        }

        if let validationMessage = Self.passwordValidationMessage(authStatus: authStatus, password: password) {
            errorMessage = validationMessage
            return
        }

        isWorking = true
        defer { isWorking = false }

        if authStatus == nil {
            do {
                authStatus = try await authManager.testConnection(
                    serverURLString: serverURLString,
                    customHeaders: customHeaders
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }

            if let validationMessage = Self.passwordValidationMessage(authStatus: authStatus, password: password) {
                errorMessage = validationMessage
                return
            }
        }

        await authManager.configure(
            serverURLString: serverURLString,
            password: password,
            customHeaders: customHeaders
        )
        errorMessage = authManager.lastErrorMessage
    }

    private func connectUniOps(authManager: AuthManager) async {
        guard !serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = APIError.invalidServerURL.localizedDescription
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let credential = try await GoogleSignInProvider.signInCredential()
            await authManager.configureUniOps(
                serverURLString: serverURLString,
                credential: credential
            )
            errorMessage = authManager.lastErrorMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    nonisolated static func passwordValidationMessage(authStatus: AuthStatusResponse?, password: String) -> String? {
        guard authStatus?.authEnabled == true else { return nil }
        // Passkey-only servers don't take a password — let configure() report the
        // specific unsupported message instead of demanding one here (#255).
        guard authStatus?.passwordAuthEnabled != false else { return nil }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPassword.isEmpty ? emptyPasswordMessage : nil
    }
}
