//
//  MenuContentView.swift
//  switch-bot-menu-bar
//
//  Root of the MenuBarExtra(.window) content. There is no public
//  `isPresented` binding for this style on macOS 14/15, so onAppear/
//  onDisappear here is the open/close signal AppStore uses to start and
//  stop its refresh loop.
//

import SwiftUI

struct MenuContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openSettings) private var openSettings
    @State private var didAppearOnce = false

    var body: some View {
        Group {
            switch store.authState {
            case .loading:
                ProgressView()
                    .frame(width: 300, height: 120)
            case .needsOnboarding:
                OnboardingView()
            case .demo, .ready:
                connectedContent
            }
        }
        .onAppear {
            store.onMenuOpened()
            if !didAppearOnce {
                didAppearOnce = true
                Task { await store.start() }
            }
        }
        .onDisappear {
            store.onMenuClosed()
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isDemoMode {
                demoBanner
            }
            if let error = store.lastError {
                errorBanner(error)
            }
            if store.isNearRateLimit {
                Label("Approaching daily API limit", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SceneListView()

                    ForEach(DeviceCategory.allCases, id: \.self) { category in
                        let devicesInCategory = store.devices.filter { store.category(for: $0) == category }
                        if !devicesInCategory.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ForEach(devicesInCategory) { device in
                                    DeviceRowView(vm: DeviceViewModel(device: device, store: store))
                                    Divider()
                                }
                            }
                        }
                    }

                    if store.devices.isEmpty {
                        Text("No devices found. Pull to refresh, or check your SwitchBot app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxHeight: 420)

            Divider()

            HStack {
                Button {
                    Task { await store.manualRefresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Settings…") { openSettings() }
                    .buttonStyle(.plain)
                    .font(.caption)

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private var demoBanner: some View {
        HStack {
            Label("Demo Mode", systemImage: "sparkles")
                .font(.caption.bold())
            Spacer()
            Button("Exit") { store.exitDemoMode() }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(6)
        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
    }

    private func errorBanner(_ error: SwitchBotError) -> some View {
        Label(error.errorDescription ?? "Something went wrong", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(2)
    }
}
