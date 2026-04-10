//
//  TEDAgent.swift
//  MeetingCrew
//
//  TED = Transcription & Executive Documentation
//  - SpeechService로 실시간 받아쓰기
//  - 5분마다 누적 텍스트를 Claude에게 보내 요약을 받아옴
//  - Action Item은 **볼드체** 마크다운으로 강조 요청
//

import Foundation
import Combine

@MainActor
final class TEDAgent: ObservableObject {

    // MARK: - Published

    @Published var transcript: String = ""
    @Published var summary: String = ""
    @Published var isSummarizing: Bool = false
    @Published var lastSummaryAt: Date? = nil
    @Published var lastError: String? = nil

    // MARK: - 내부 상태

    let speech = SpeechService()
    private var cancellables = Set<AnyCancellable>()
    private var summarizeTimer: Timer?

    /// 5분 간격으로 자동 요약 (스펙: 5분마다).
    private let summarizeInterval: TimeInterval = 5 * 60

    // MARK: - Init

    init() {
        // SpeechService의 transcript를 TEDAgent.transcript로 미러링
        speech.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.transcript = newValue
            }
            .store(in: &cancellables)
    }

    // MARK: - 세션 제어

    func startRecording() throws {
        try speech.start()
        startSummarizeTimer()
    }

    func pauseRecording() {
        speech.pause()
        summarizeTimer?.invalidate()
        summarizeTimer = nil
    }

    func resumeRecording() throws {
        try speech.resume()
        startSummarizeTimer()
    }

    func stopRecording() {
        speech.stop()
        summarizeTimer?.invalidate()
        summarizeTimer = nil
    }

    func reset() {
        speech.reset()
        transcript = ""
        summary = ""
        lastSummaryAt = nil
        lastError = nil
    }

    // MARK: - 요약 타이머

    private func startSummarizeTimer() {
        summarizeTimer?.invalidate()
        summarizeTimer = Timer.scheduledTimer(withTimeInterval: summarizeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.summarize()
            }
        }
    }

    // MARK: - Claude 호출

    /// 현재 transcript를 Claude에게 보내 요약을 받아온다. 사용자 버튼으로도 호출 가능.
    func summarize() async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 20 else { return }

        isSummarizing = true
        lastError = nil
        defer { isSummarizing = false }

        let systemPrompt = """
        당신은 회의록을 깔끔하게 정리하는 비서입니다.
        다음 규칙을 지켜 한국어로 응답하세요:

        1. 3~6개의 bullet로 핵심만 요약
        2. 핵심 결정사항, 해야 할 일(Action Item)은 반드시 **굵게** (마크다운)로 강조
        3. 담당자/기한이 언급됐다면 bullet에 포함
        4. 반드시 마크다운 형식, 코드블록(```)은 쓰지 말 것
        5. 머리말이나 사족 없이 bullet 리스트만 출력
        """

        do {
            let result = try await ClaudeAPIService.shared.sendMessage(
                system: systemPrompt,
                userText: text,
                maxTokens: 800,
                temperature: 0.3
            )
            self.summary = result
            self.lastSummaryAt = Date()
        } catch {
            self.lastError = error.localizedDescription
        }
    }
}
