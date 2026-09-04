//
//  SwitchBotClient.swift
//  switch-bot-menu-bar
//

import Foundation

struct SwitchBotCredentials: Sendable, Equatable {
    let token: String
    let secret: String
}

/// Thin wrapper over the SwitchBot v1.1 REST API.
/// https://github.com/OpenWonderLabs/SwitchBotAPI
struct SwitchBotClient: Sendable {
    static let baseURL = URL(string: "https://api.switch-bot.com")!

    let httpClient: HTTPClient
    let credentials: SwitchBotCredentials
    let now: @Sendable () -> Date
    let nonce: @Sendable () -> String

    init(
        httpClient: HTTPClient,
        credentials: SwitchBotCredentials,
        now: @escaping @Sendable () -> Date = { Date() },
        nonce: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.httpClient = httpClient
        self.credentials = credentials
        self.now = now
        self.nonce = nonce
    }

    // MARK: - Endpoints

    func devices() async throws -> [Device] {
        let envelope: APIEnvelope<DeviceListBody> = try await get("/v1.1/devices")
        return try envelope.unwrap().devices
    }

    func status(deviceId: String) async throws -> DeviceStatus {
        let envelope: APIEnvelope<DeviceStatus> = try await get("/v1.1/devices/\(deviceId)/status")
        return try envelope.unwrap()
    }

    @discardableResult
    func sendCommand(_ command: DeviceCommand, to deviceId: String) async throws -> Bool {
        let envelope: APIEnvelope<EmptyBody> = try await post(
            "/v1.1/devices/\(deviceId)/commands", body: command
        )
        _ = try envelope.unwrap()
        return true
    }

    func scenes() async throws -> [SceneItem] {
        let envelope: APIEnvelope<[SceneItem]> = try await get("/v1.1/scenes")
        return try envelope.unwrap()
    }

    @discardableResult
    func executeScene(_ sceneId: String) async throws -> Bool {
        let envelope: APIEnvelope<EmptyBody> = try await post(
            "/v1.1/scenes/\(sceneId)/execute", body: EmptyEncodable()
        )
        _ = try envelope.unwrap()
        return true
    }

    // MARK: - Request plumbing

    private func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await send(path: path, method: "GET", body: Optional<EmptyEncodable>.none)
    }

    private func post<Body: Encodable, Response: Decodable & Sendable>(
        _ path: String, body: Body
    ) async throws -> Response {
        try await send(path: path, method: "POST", body: body)
    }

    private func send<Body: Encodable, Response: Decodable & Sendable>(
        path: String, method: String, body: Body?
    ) async throws -> Response {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method

        let timestamp = RequestSigner.timestampMillis(now: now())
        let nonceValue = nonce()
        let signature = RequestSigner.sign(
            token: credentials.token, secret: credentials.secret,
            timestampMillis: timestamp, nonce: nonceValue
        )

        request.setValue(credentials.token, forHTTPHeaderField: "Authorization")
        request.setValue(signature, forHTTPHeaderField: "sign")
        request.setValue(timestamp, forHTTPHeaderField: "t")
        request.setValue(nonceValue, forHTTPHeaderField: "nonce")
        request.setValue("application/json; charset=utf8", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await httpClient.send(request)

        guard (200...299).contains(response.statusCode) else {
            throw SwitchBotError.transport("HTTP \(response.statusCode)")
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SwitchBotError.decoding(String(describing: error))
        }
    }
}

/// Encodable placeholder for requests with no meaningful body but where a
/// generic `Body: Encodable` parameter still needs a concrete type.
private struct EmptyEncodable: Encodable {}
