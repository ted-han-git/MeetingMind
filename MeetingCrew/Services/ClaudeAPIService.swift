//
//  ClaudeAPIService.swift
//  MeetingCrew
//
//  Anthropic Claude Messages API 래퍼.
//  - 모델: claude-sonnet-4-20250514
//  - API 키는 UserDefaults에 저장되며, 사용자가 설정 화면에서 입력한다.
//

import Foundation

// MARK: - Request / Response 모델

struct ClaudeMessage: Codable {
    let role: String    // "user" or "assistant"
    let content: String
}

private struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    let temperature: Double?
}

private struct ClaudeResponseContent: Codable {
    let type: String
    let text: String?
}

private struct ClaudeResponse: Codable {
    let id: String?
    let content: [ClaudeResponseContent]
    let stop_reason: String?
}

private struct ClaudeAPIErrorBody: Codable {
    struct ErrorDetail: Codable {
        let type: String
        let message: String
    }
    let type: String
    let error: ErrorDetail
}

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case missingKey
    case network(String)
    case decoding(String)
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Claude API Key가 설정되지 않았습니다. 설정 화면에서 입력해주세요."
        case .network(let msg):
            return "네트워크 오류: \(msg)"
        case .decoding(let msg):
            return "응답 파싱 오류: \(msg)"
        case .http(let code, let msg):
            return "HTTP \(code): \(msg)"
        }
    }
}

// MARK: - Service

final class ClaudeAPIService {

    static let shared = ClaudeAPIService()

    /// 사용 모델. 스펙에 명시된 Sonnet 4.
    let model: String = "claude-sonnet-4-20250514"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let keyDefaultsName = "meetingcrew.claude.apiKey"

    /// UserDefaults 기반 API 키 저장. (프로덕션이라면 Keychain 사용 권장)
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: keyDefaultsName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: keyDefaultsName) }
    }

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private init() {}

    // MARK: - 요청

    /// 단발성 메시지 전송. 시스템 프롬프트 + 유저 메시지 → 텍스트 응답.
    func sendMessage(
        system: String?,
        userText: String,
        maxTokens: Int = 1024,
        temperature: Double? = 0.3
    ) async throws -> String {

        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ClaudeAPIError.missingKey }

        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [ClaudeMessage(role: "user", content: userText)],
            temperature: temperature
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(trimmed, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw ClaudeAPIError.decoding("요청 인코딩 실패: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeAPIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.network("Invalid HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            // API 에러 본문 파싱 시도
            if let errorBody = try? JSONDecoder().decode(ClaudeAPIErrorBody.self, from: data) {
                throw ClaudeAPIError.http(status: http.statusCode, message: errorBody.error.message)
            }
            let raw = String(data: data, encoding: .utf8) ?? "(empty)"
            throw ClaudeAPIError.http(status: http.statusCode, message: raw)
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            let joined = decoded.content.compactMap { $0.text }.joined(separator: "\n")
            return joined.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw ClaudeAPIError.decoding(error.localizedDescription)
        }
    }
}
