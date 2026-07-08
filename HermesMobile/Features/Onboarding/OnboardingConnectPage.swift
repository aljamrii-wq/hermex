import SwiftUI

enum OnboardingConnectField: Hashable {
    case serverURL
    case password
}

struct OnboardingConnectPage: View {
    @Bindable var viewModel: OnboardingViewModel
    @Bindable var authManager: AuthManager
    @FocusState.Binding var focusedField: OnboardingConnectField?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingAdvanced = false

    private var canSubmit: Bool {
        !viewModel.serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitConnection() {
        guard canSubmit else { return }
        Task { await viewModel.connect(authManager: authManager) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(viewModel.authMode == .uniOps ? String(localized: "Enter the UniOps Tailscale URL, then sign in with your owner Google account.") : String(localized: "Enter the Tailscale URL your agent returned, for example `http://<tailnet-ip>:8787`."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker("Auth Mode", selection: $viewModel.authMode) {
                    ForEach(Array(OnboardingViewModel.AuthMode.allCases)) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    OnboardingField(systemImage: "link", title: String(localized: "Server URL")) {
                        ZStack(alignment: .leading) {
                            if viewModel.serverURLString.isEmpty {
                                Text(verbatim: viewModel.authMode == .uniOps ? "http://uniops.<tailnet>.ts.net" : "http://100.64.0.1:8787")
                                    .foregroundStyle(.white.opacity(0.38))
                                    .allowsHitTesting(false)
                            }

                            TextField("", text: $viewModel.serverURLString)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .foregroundStyle(.white)
                                .submitLabel(.go)
                                .tint(Color(red: 1.0, green: 0.74, blue: 0.10))
                                .focused($focusedField, equals: .serverURL)
                                .onSubmit(submitConnection)
                        }
                    }

                    if viewModel.isPasswordRequired {
                        OnboardingField(systemImage: "key.fill", title: String(localized: "Password")) {
                            SecureField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("Server password")
                                    .foregroundStyle(.white.opacity(0.38))
                            )
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit(submitConnection)
                        }
                    }
                }

                if viewModel.authMode == .hermex {
                    DisclosureGroup(isExpanded: $isShowingAdvanced) {
                        CustomHeadersEditor(headers: $viewModel.customHeaders, style: .onboarding)
                            .padding(.top, 10)
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .tint(.white.opacity(0.6))
                }

                if viewModel.isWorking {
                    OnboardingStatusBanner(
                        text: viewModel.authMode == .uniOps ? String(localized: "Signing in...") : String(localized: "Checking server..."),
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .white.opacity(0.7),
                        showsProgress: true
                    )
                }

                if let connectionMessage = viewModel.connectionMessage {
                    OnboardingStatusBanner(
                        text: connectionMessage,
                        systemImage: "checkmark.circle.fill",
                        tint: Color(red: 0.45, green: 0.92, blue: 0.56)
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    OnboardingStatusBanner(
                        text: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: Color(red: 1.0, green: 0.47, blue: 0.34)
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
