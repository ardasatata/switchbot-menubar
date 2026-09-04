//
//  OnboardingModel.swift
//  switch-bot-menu-bar
//

import Foundation
import Observation

@Observable
@MainActor
final class OnboardingModel {
    var token: String = ""
    var secret: String = ""
    private(set) var isValidating = false
    private(set) var errorMessage: String?

    var canSubmit: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isValidating
    }

    /// Validates against the live API (via `store.saveCredentials`, which
    /// calls GET /v1.1/devices before persisting anything) and reports
    /// success/failure back to the view.
    func submit(store: AppStore) async -> Bool {
        errorMessage = nil
        isValidating = true
        defer { isValidating = false }

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await store.saveCredentials(token: trimmedToken, secret: trimmedSecret)
            return true
        } catch let error as SwitchBotError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
