//
//  SceneItem.swift
//  switch-bot-menu-bar
//

import Foundation

struct SceneItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id = "sceneId"
        case name = "sceneName"
    }
}
