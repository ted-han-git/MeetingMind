//
//  TEDView.swift
//  MeetingCrew
//
//  왼쪽 패널 (TED). 상단 60% 실시간 받아쓰기, 하단 40% 요약.
//

import SwiftUI

struct TEDView: View {
    @EnvironmentObject var store: MeetingSessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            GeometryReader { geo in
                VStack(spacing: 0) {
                    transcriptSection
                        .frame(height: geo.size.height * 0.6)
                    Divider()
                    summarySection
                        .frame(height: geo.size.height * 0.4)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("🎙️")
                .font(.title2)
            VStack(alignment: .leading, spacing: 0) {
                Text("TED")
                    .font(.headline)
                Text("Transcription & Executive Documentation")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.ted.isSummarizing {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 받아쓰기

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("실시간 받아쓰기", systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if store.isRecording && !store.isPaused {
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(store.ted.transcript.isEmpty ? placeholderText : store.ted.transcript)
                        .font(.body)
                        .foregroundStyle(store.ted.transcript.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                        .id("transcript_bottom")
                }
                .onChange(of: store.ted.transcript) { _, _ in
                    withAnimation {
                        proxy.scrollTo("transcript_bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var placeholderText: String {
        "상단의 '녹음 시작' 버튼을 눌러 회의를 시작하세요.\n한국어 음성을 실시간으로 텍스트로 변환합니다."
    }

    // MARK: - 요약

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("요약", systemImage: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let at = store.ted.lastSummaryAt {
                    Text(at, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("지금 요약") {
                    Task { await store.ted.summarize() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .disabled(store.ted.transcript.isEmpty || store.ted.isSummarizing)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                if store.ted.summary.isEmpty {
                    Text("5분마다 자동으로 요약이 생성됩니다.\n핵심 결정사항(Action Item)은 **굵게** 표시됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    MarkdownText(text: store.ted.summary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                }

                if let err = store.ted.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}

/// Claude가 마크다운으로 볼드체(**)를 반환하는 요약을 렌더링.
struct MarkdownText: View {
    let text: String
    var body: some View {
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attr)
        } else {
            Text(text)
        }
    }
}
