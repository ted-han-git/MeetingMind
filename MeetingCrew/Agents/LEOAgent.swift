//
//  LEOAgent.swift
//  MeetingCrew
//
//  LEO = Language & Explanation Officer
//  - TED의 transcript를 주기적으로 스캔해 전문용어/약어를 감지
//  - Claude에게 JSON 배열 형태로 [{term, explanation}] 요청
//  - 패널 하단 절반은 사용자의 자유 메모 (notes)
//

import Foundation
import Combine

@MainActor
final class LEOAgent: ObservableObject {

    // MARK: - Published

    @Published var terms: [DetectedTerm] = []
    @Published var notes: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var lastError: String? = nil

    // MARK: - 내부 상태

    private weak var ted: TEDAgent?
    private var timer: Timer?
    private var lastAnalyzedLength: Int = 0

    /// 용어 감지 주기 (초)
    private let detectInterval: TimeInterval = 45

    /// 이 길이 이상 transcript가 증가했을 때만 재분석 (토큰 낭비 방지)
    private let minDeltaChars: Int = 60

    // MARK: - Binding

    func bind(to ted: TEDAgent) {
        self.ted = ted
    }

    // MARK: - 제어

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: detectInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.detectTerms()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        terms.removeAll()
        notes = ""
        lastAnalyzedLength = 0
        lastError = nil
    }

    // MARK: - Claude 호출

    func detectTerms() async {
        guard let ted else { return }
        let text = ted.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text.count >= lastAnalyzedLength + minDeltaChars else { return }

        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        let existing = terms.map { $0.term }.joined(separator: ", ")

        let systemPrompt = """
        당신은 회의 중 등장하는 어려운 전문 용어, 약어, 업계 용어를 감지해 일반인도 이해할 수 있게
        친절히 풀어 설명하는 도우미입니다.

        아래 회의 받아쓰기 텍스트에서 '설명이 필요해 보이는' 용어를 최대 5개까지 골라,
        반드시 아래 형식의 **순수한 JSON 배열만** 응답하세요. 마크다운 코드블록(```)도 쓰지 마세요.

        [
          {"term": "용어", "explanation": "한국어로 2문장 이내 설명"}
        ]

        - 이미 설명된 용어는 제외: \(existing.isEmpty ? "(없음)" : existing)
        - 새롭게 설명이 필요한 것이 없으면 빈 배열 [] 만 반환
        - 설명은 반드시 한국어
        """

        do {
            let response = try await ClaudeAPIService.shared.sendMessage(
                system: systemPrompt,
                userText: text,
                maxTokens: 700,
                temperature: 0.2
            )
            let jsonString = Self.extractJSONArray(from: response)

            struct Item: Codable {
                let term: String
                let explanation: String
            }

            if let data = jsonString.data(using: .utf8),
               let items = try? JSONDecoder().decode([Item].self, from: data) {
                for item in items {
                    let term = item.term.trimmingCharacters(in: .whitespacesAndNewlines)
                    let explanation = item.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !term.isEmpty, !explanation.isEmpty else { continue }
                    let alreadyExists = terms.contains {
                        $0.term.caseInsensitiveCompare(term) == .orderedSame
                    }
                    if !alreadyExists {
                        terms.append(DetectedTerm(term: term, explanation: explanation))
                    }
                }
            }

            lastAnalyzedLength = text.count
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    /// Claude가 JSON 외에 설명을 덧붙일 경우를 대비해 `[ ... ]` 블록만 추출.
    static func extractJSONArray(from text: String) -> String {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start <= end else {
            return "[]"
        }
        return String(text[start...end])
    }

    func remove(_ term: DetectedTerm) {
        terms.removeAll { $0.id == term.id }
    }
}
