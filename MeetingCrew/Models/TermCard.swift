//
//  TermCard.swift
//  MeetingCrew
//
//  LEO Agent가 감지한 전문용어 카드. 런타임에서만 사용되는 값 타입이며,
//  세션 저장 시 JSON으로 직렬화되어 PersistedMeetingSession에 포함된다.
//

import Foundation

struct DetectedTerm: Identifiable, Codable, Hashable {
    var id: UUID
    var term: String
    var explanation: String
    var detectedAt: Date

    init(id: UUID = UUID(), term: String, explanation: String, detectedAt: Date = Date()) {
        self.id = id
        self.term = term
        self.explanation = explanation
        self.detectedAt = detectedAt
    }
}
