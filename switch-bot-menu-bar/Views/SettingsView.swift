//
//  SettingsView.swift
//  switch-bot-menu-bar
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showClearConfirmation = false
    @State private var replacementModel = OnboardingModel()
    @State private var isReplacing = false

    var body: some View {
        Form {
            Section("Account") {
                if store.isDemoMode {
                    Label("Using demo data — no account connected", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                    Button("Exit Demo Mode") { store.exitDemoMode() }
                } else if store.authState == .ready {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    if isReplacing {
                        replacementForm
                    } else {
                        Button("Replace credentials…") { isReplacing = true }
                        Button("Clear credentials", role: .destructive) { showClearConfirmation = true }
                    }
                } else {
                    Label("Not connected", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Refresh") {
                Picker("Background refresh", selection: Binding(
                    get: { store.backgroundRefreshMinutes ?? 0 },
                    set: { store.backgroundRefreshMinutes = $0 == 0 ? nil : $0 }
                )) {
                    Text("Off (recommended)").tag(0)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                }
                if let minutes = store.backgroundRefreshMinutes, !store.devices.isEmpty {
                    let callsPerDay = store.devices.count * (1440 / max(minutes, 1))
                    Text("Estimated cost: ~\(callsPerDay) calls/day of the 10,000/day limit")
                        .font(.caption)
                        .foregroundStyle(callsPerDay > 6000 ? .orange : .secondary)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }

            Section {
                Link("SwitchBot API on GitHub", destination: URL(string: "https://github.com/OpenWonderLabs/SwitchBotAPI")!)
                Text("Not affiliated with SwitchBot / Wonderlabs. Uses your personal API token against your own devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 420)
        .confirmationDialog("Clear stored credentials?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) { try? store.clearCredentials() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your Open Token and Secret Key again to reconnect.")
        }
    }

    private var replacementForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            SecureField("New Open Token", text: Binding(get: { replacementModel.token }, set: { replacementModel.token = $0 }))
            SecureField("New Secret Key", text: Binding(get: { replacementModel.secret }, set: { replacementModel.secret = $0 }))
            if let error = replacementModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Save") {
                    Task {
                        if await replacementModel.submit(store: store) {
                            isReplacing = false
                        }
                    }
                }
                .disabled(!replacementModel.canSubmit)
                Button("Cancel") { isReplacing = false }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppStore(credentialStore: InMemoryCredentialStore(), diskCache: DiskCache()))
}
