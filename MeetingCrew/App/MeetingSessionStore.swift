//
//  MeetingSessionStore.swift
//  MeetingCrew
//
//  세 Agent(TED / LEO / MAX)의 런타임 상태와 전체 회의 세션 제어를 담당하는 Store.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MeetingSessionStore: ObservableObject {

    // 세 Agent (내부 ObservableObject)
    let ted = TEDAgent()
    let leo = LEOAgent()
    let max = MAXAgent()

    // 세션 상태
    @Published var title: String = "새 회의"
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var startedAt: Date? = nil
    @Published var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        leo.bind(to: ted)
        max.bind(to: ted)

        // 자식 ObservableObject의 변경을 store로 포워딩
        ted.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        leo.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        max.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - 세션 제어

    func start() {
        guard !isRecording else { return }
        Task {
            await ted.speech.requestAuthorization()
            if ted.speech.isAuthorized == false {
                self.errorMessage = ted.speech.errorMessage ?? "권한이 필요합니다."
                return
            }
            do {
                try ted.startRecording()
                leo.start()
                max.start()
                self.isRecording = true
                self.isPaused = false
                self.startedAt = Date()
            } catch {
                self.errorMessage = "녹음 시작 실패: \(error.localizedDescription)"
            }
        }
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        ted.pauseRecording()
        isPaused = true
    }

    func resume() {
        guard isRecording, isPaused else { return }
        do {
            try ted.resumeRecording()
            isPaused = false
        } catch {
            errorMessage = "재개 실패: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRecording else { return }
        ted.stopRecording()
        leo.stop()
        max.stop()
        isRecording = false
        isPaused = false
    }

    func resetAll() {
        stop()
        ted.reset()
        leo.reset()
        max.reset()
        title = "새 회의"
        startedAt = nil
        errorMessage = nil
    }

    // MARK: - 저장

    /// 현재 회의 상태를 SwiftData에 영속화할 수 있는 형태로 직렬화.
    func makePersisted() -> PersistedMeetingSession {
        let termsData = (try? JSONEncoder().encode(leo.terms)) ?? Data()
        let questionsData = (try? JSONEncoder().encode(max.questions)) ?? Data()
        return PersistedMeetingSession(
            id: UUID(),
            title: title,
            startedAt: startedAt ?? Date(),
            endedAt: Date(),
            transcript: ted.transcript,
            summary: ted.summary,
            notes: leo.notes,
            termsJSON: String(data: termsData, encoding: .utf8) ?? "[]",
            questionsJSON: String(data: questionsData, encoding: .utf8) ?? "[]"
        )
    }

    /// 저장된 세션을 다시 로드해서 현재 상태로 복원.
    func load(_ persisted: PersistedMeetingSession) {
        stop()
        title = persisted.title
        startedAt = persisted.startedAt
        ted.transcript = persisted.transcript
        ted.summary = persisted.summary
        leo.notes = persisted.notes

        if let data = persisted.termsJSON.data(using: .utf8),
           let terms = try? JSONDecoder().decode([DetectedTerm].self, from: data) {
            leo.terms = terms
        }
        if let data = persisted.questionsJSON.data(using: .utf8),
           let qs = try? JSONDecoder().decode([CheckQuestion].self, from: data) {
            max.questions = qs
        }
    }
}
