//
//  MAXAgent.swift
//  MeetingCrew
//
//  MAX = Meeting Analyst & question eXpert
//  - 회의 맥락을 분석해 '놓친 질문 / 확인 필요 항목'을 능동 제안
//  - 숫자/날짜/담당자/기한/예산처럼 애매하게 넘어간 포인트를 포착
//  - 30초 주기로 Claude 호출, 응답은 JSON 배열
//

import Foundation
import Combine

@MainActor
final class MAXAgent: ObservableObject {

    // MARK: - Published

    @Published var questions: [CheckQuestion] = []
    @Published var isAnalyzing: Bool = false
    @Published var lastError: String? = nil

    // MARK: - 내부 상태

    private weak var ted: TEDAgent?
    private var timer: Timer?
    private var lastAnalyzedLength: Int = 0

    /// 체크 항목 생성 주기 (초). 스펙: 15~30초 간격 → 30초로 설정.
    private let analyzeInterval: TimeInterval = 30

    /// transcript가 이만큼 늘어나야 재분석
    private let minDeltaChars: Int = 80

    // MARK: - Binding

    func bind(to ted: TEDAgent) {
        self.ted = ted
    }

    // MARK: - 제어

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: analyzeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.analyze()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        questions.removeAll()
        lastAnalyzedLength = 0
        lastError = nil
    }

    // MARK: - Claude 호출

    func analyze() async {
        guard let ted else { return }
        let text = ted.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text.count >= lastAnalyzedLength + minDeltaChars else { return }

        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        let pending = questions
            .filter { $0.status == .pending }
            .map { "- \($0.question)" }
            .joined(separator: "\n")

        let systemPrompt = """
        당신은 회의에서 놓치기 쉬운 부분을 집어주는 꼼꼼한 분석가입니다.
        아래 회의 받아쓰기 텍스트를 읽고, "아직 확인되지 않았거나 애매하게 넘어간" 포인트를
        '질문 형태'로 최대 3개 뽑아주세요.

        특히 다음 카테고리에 주목하세요:
        - 구체적 숫자/금액/수치
        - 날짜, 마감일, 기한
        - 담당자가 정해지지 않은 Action Item
        - 책임 소재가 모호한 결정
        - 후속 확인이 필요한 외부 의존성

        반드시 **순수한 JSON 배열**만 응답하세요. 코드블록(```)과 설명은 쓰지 마세요.
        예시:
        ["담당자 A는 어떤 일정까지 리포트를 공유하나요?", "예산 상한은 정확히 얼마인가요?"]

        이미 제안된 질문은 제외하세요:
        \(pending.isEmpty ? "(없음)" : pending)

        새로 제안할 것이 없으면 빈 배열 [] 만 반환. 모든 질문은 한국어로.
        """

        do {
            let response = try await ClaudeAPIService.shared.sendMessage(
                system: systemPrompt,
                userText: text,
                maxTokens: 600,
                temperature: 0.4
            )
            let jsonString = LEOAgent.extractJSONArray(from: response)
            if let data = jsonString.data(using: .utf8),
               let items = try? JSONDecoder().decode([String].self, from: data) {
                for q in items {
                    let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    let duplicate = questions.contains { $0.question == trimmed }
                    if !duplicate {
                        questions.append(CheckQuestion(question: trimmed))
                    }
                }
            }
            lastAnalyzedLength = text.count
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 상태 변경

    func update(_ q: CheckQuestion, to status: CheckQuestion.Status) {
        guard let idx = questions.firstIndex(where: { $0.id == q.id }) else { return }
        questions[idx].status = status
    }

    /// 화면에 표시할 질문 (deleted 제외)
    var visibleQuestions: [CheckQuestion] {
        questions.filter { $0.status != .deleted }
    }
}
