//
//  HistoryView.swift
//  MeetingCrew
//
//  저장된 회의록(PersistedMeetingSession) 목록 및 상세 보기.
//  SwiftData @Query로 최근 순 정렬.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var store: MeetingSessionStore

    @Query(sort: \PersistedMeetingSession.startedAt, order: .reverse)
    private var sessions: [PersistedMeetingSession]

    @State private var selected: PersistedMeetingSession?
    @State private var showDetail: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("저장된 회의록")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("저장된 회의록이 없습니다.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions, id: \.id) { session in
                        HistoryRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selected = session
                                showDetail = true
                            }
                    }
                    .onDelete(perform: delete)
                }
                #if os(macOS)
                .listStyle(.inset)
                #endif
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .sheet(isPresented: $showDetail) {
            if let session = selected {
                HistoryDetailView(session: session) {
                    store.load(session)
                    showDetail = false
                    dismiss()
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(sessions[idx])
        }
        try? modelContext.save()
    }
}

struct HistoryRow: View {
    let session: PersistedMeetingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)
            HStack(spacing: 12) {
                Label(session.startedAt.formatted(date: .numeric, time: .shortened), systemImage: "calendar")
                Label(durationText, systemImage: "clock")
                Label("\(session.transcript.count)자", systemImage: "text.alignleft")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        let interval = session.endedAt.timeIntervalSince(session.startedAt)
        let minutes = Int(interval / 60)
        return "\(minutes)분"
    }
}

struct HistoryDetailView: View {
    let session: PersistedMeetingSession
    let onLoad: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.title).font(.title2.bold())
                    Text(session.startedAt.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("현재 세션으로 불러오기") {
                    onLoad()
                }
                .buttonStyle(.borderedProminent)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "📝 요약") {
                        if session.summary.isEmpty {
                            Text("요약 없음").foregroundStyle(.secondary)
                        } else {
                            MarkdownText(text: session.summary)
                        }
                    }
                    section(title: "🎙️ 받아쓰기") {
                        Text(session.transcript.isEmpty ? "내용 없음" : session.transcript)
                            .foregroundStyle(session.transcript.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                    }
                    section(title: "🗒️ 메모") {
                        Text(session.notes.isEmpty ? "메모 없음" : session.notes)
                            .foregroundStyle(session.notes.isEmpty ? .secondary : .primary)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
    }
}
