//
//  MAXView.swift
//  MeetingCrew
//
//  오른쪽 패널 (MAX). AI가 제안하는 '확인이 필요해 보이는' 질문 카드 목록.
//  각 카드는 완료/보류/삭제 액션을 제공한다.
//

import SwiftUI

struct MAXView: View {
    @EnvironmentObject var store: MeetingSessionStore
    @State private var filter: Filter = .pending

    enum Filter: String, CaseIterable, Identifiable {
        case pending = "확인 필요"
        case done = "완료"
        case held = "보류"
        case all = "전체"

        var id: String { rawValue }

        func apply(_ q: CheckQuestion) -> Bool {
            switch self {
            case .pending: return q.status == .pending
            case .done:    return q.status == .done
            case .held:    return q.status == .held
            case .all:     return q.status != .deleted
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            list
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("❓")
                .font(.title2)
            VStack(alignment: .leading, spacing: 0) {
                Text("MAX")
                    .font(.headline)
                Text("Meeting Analyst & question eXpert")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.max.isAnalyzing {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var toolbar: some View {
        HStack {
            Picker("필터", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button("지금 확인") {
                Task { await store.max.analyze() }
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .disabled(store.ted.transcript.isEmpty || store.max.isAnalyzing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - 리스트

    private var list: some View {
        let filtered = store.max.questions.filter { filter.apply($0) }

        return ScrollView {
            LazyVStack(spacing: 10) {
                if filtered.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("회의가 진행되면 '확인이 필요해 보이는' 항목을\nAI가 자동으로 제안합니다.")
                            .multilineTextAlignment(.center)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(filtered) { q in
                        QuestionCardRow(q: q) { newStatus in
                            store.max.update(q, to: newStatus)
                        }
                    }
                    .padding(.horizontal, 12)
                }

                if let err = store.max.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 10)
        }
    }
}

struct QuestionCardRow: View {
    let q: CheckQuestion
    let onUpdate: (CheckQuestion.Status) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .padding(.top, 3)
                Text(q.question)
                    .font(.body)
                    .strikethrough(q.status == .done)
                    .foregroundStyle(q.status == .held ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }

            HStack(spacing: 6) {
                Button {
                    onUpdate(.done)
                } label: {
                    Label("완료", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.green)

                Button {
                    onUpdate(.held)
                } label: {
                    Label("보류", systemImage: "hourglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)

                Button {
                    onUpdate(.deleted)
                } label: {
                    Label("삭제", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)

                Spacer()
                Text(q.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusIcon: String {
        switch q.status {
        case .pending: return "questionmark.circle.fill"
        case .done:    return "checkmark.circle.fill"
        case .held:    return "pause.circle.fill"
        case .deleted: return "trash.circle.fill"
        }
    }

    private var statusColor: Color {
        switch q.status {
        case .pending: return .orange
        case .done:    return .green
        case .held:    return .gray
        case .deleted: return .red
        }
    }

    private var cardBackground: Color {
        switch q.status {
        case .pending: return Color.orange.opacity(0.08)
        case .done:    return Color.green.opacity(0.08)
        case .held:    return Color.gray.opacity(0.08)
        case .deleted: return Color.red.opacity(0.08)
        }
    }
}
