//
//  SceneListView.swift
//  switch-bot-menu-bar
//

import SwiftUI

struct SceneListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if !store.scenes.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scenes")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(store.scenes) { scene in
                    Button {
                        Task { await store.executeScene(scene) }
                    } label: {
                        Label(scene.name, systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
