//
//  OnboardingView.swift
//  switch-bot-menu-bar
//
//  Shown on first launch (no credentials in the Keychain yet). Offers both
//  a real-token path and "Try the demo" — the latter matters for App Review,
//  which has no SwitchBot account, and for a prospective user evaluating
//  the app before hunting down a token.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var model = OnboardingModel()
    @FocusState private var focusedField: Field?

    private enum Field { case token, secret }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect SwitchBot")
                    .font(.title3.bold())
                Text("Enter your Open Token and Secret Key, or try the app with simulated devices.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Open Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Paste your token", text: Binding(get: { model.token }, set: { model.token = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .token)

                Text("Secret Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Paste your secret key", text: Binding(get: { model.secret }, set: { model.secret = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .secret)
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    if await model.submit(store: store) {
                        focusedField = nil
                    }
                }
            } label: {
                if model.isValidating {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSubmit)

            Divider()

            Button {
                store.enterDemoMode()
            } label: {
                Text("Try the demo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Link("How do I get a token?", destination: URL(string: "https://github.com/OpenWonderLabs/SwitchBotAPI#getting-started")!)
                    .font(.caption)

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

#Preview {
    OnboardingView()
        .environment(AppStore(credentialStore: InMemoryCredentialStore(), diskCache: DiskCache()))
}
