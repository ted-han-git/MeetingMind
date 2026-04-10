//
//  QuestionCard.swift
//  MeetingCrew
//
//  MAX Agent가 제안한 체크 질문. 사용자는 완료/보류/삭제로 상태를 변경할 수 있다.
//

import Foundation

struct CheckQuestion: Identifiable, Codable, Hashable {
    var id: UUID
    var question: String
    var rationale: String
    var status: Status
    var createdAt: Date

    enum Status: String, Codable, CaseIterable {
        case pending  // 확인 필요 (기본)
        case done     // 완료
        case held     // 보류
        case deleted  // 삭제됨(숨김)
    }

    init(
        id: UUID = UUID(),
        question: String,
        rationale: String = "",
        status: Status = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.question = question
        self.rationale = rationale
        self.status = status
        self.createdAt = createdAt
    }
}
