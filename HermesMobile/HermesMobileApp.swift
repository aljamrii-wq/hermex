import SwiftUI
import SwiftData
import UIKit

@main
struct HermesMobileApp: App {
    @State private var authManager = AuthManager()
    @AppStorage(AppTheme.storageKey) private var appThemeRawValue = AppTheme.system.rawValue
    @UIApplicationDelegateAdaptor(UniOpsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Launch argument hook so the Streaming Lab can be opened without
            // UI navigation (agent-driven simulator diagnosis, issue #234):
            // `xcrun simctl launch <udid> com.uzairansar.hermesmobile --streaming-lab`
            if ProcessInfo.processInfo.arguments.contains("--streaming-lab") {
                NavigationStack {
                    StreamingLabView()
                }
            } else {
                ContentView(authManager: authManager)
                    .preferredColorScheme(AppTheme.storedValue(appThemeRawValue).colorScheme)
            }
            #else
            ContentView(authManager: authManager)
                .preferredColorScheme(AppTheme.storedValue(appThemeRawValue).colorScheme)
            #endif
        }
        .modelContainer(for: [CachedSession.self, CachedMessage.self])
    }
}

final class UniOpsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .uniOpsAPNsTokenDidChange, object: token)
    }
}
