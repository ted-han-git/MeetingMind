//
//  MeetingSession.swift
//  MeetingCrew
//
//  SwiftData 로컬 영속화를 위한 모델. 회의 한 건의 스냅샷을 저장한다.
//

import Foundation
import SwiftData

@Model
final class PersistedMeetingSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date
    var transcript: String
    var summary: String
    var notes: String

    /// [DetectedTerm] JSON 인코딩
    var termsJSON: String
    /// [CheckQuestion] JSON 인코딩
    var questionsJSON: String

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date,
        endedAt: Date,
        transcript: String,
        summary: String,
        notes: String,
        termsJSON: String,
        questionsJSON: String
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.summary = summary
        self.notes = notes
        self.termsJSON = termsJSON
        self.questionsJSON = questionsJSON
    }
}
