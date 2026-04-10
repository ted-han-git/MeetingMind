//
//  LEOView.swift
//  MeetingCrew
//
//  가운데 패널 (LEO). 상단 절반은 자동 감지된 용어 카드, 하단 절반은 자유 메모장.
//

import SwiftUI

struct LEOView: View {
    @EnvironmentObject var store: MeetingSessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            GeometryReader { geo in
                VStack(spacing: 0) {
                    termsSection
                        .frame(height: geo.size.height * 0.5)
                    Divider()
                    notesSection
                        .frame(height: geo.size.height * 0.5)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("📚")
                .font(.title2)
            VStack(alignment: .leading, spacing: 0) {
                Text("LEO")
                    .font(.headline)
                Text("Language & Explanation Officer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.leo.isAnalyzing {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 용어 카드

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("자동 감지된 용어", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.leo.terms.count)개")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("지금 분석") {
                    Task { await store.leo.detectTerms() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .disabled(store.ted.transcript.isEmpty || store.leo.isAnalyzing)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if store.leo.terms.isEmpty {
                        Text("TED가 받아쓴 텍스트에서 전문용어를 자동으로 찾아 설명해드립니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    } else {
                        ForEach(store.leo.terms) { term in
                            TermCardRow(term: term) {
                                store.leo.remove(term)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 8)

                if let err = store.leo.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    // MARK: - 메모장

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("내 메모", systemImage: "pencil.and.scribble")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.leo.notes.count)자")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            TextEditor(text: Binding(
                get: { store.leo.notes },
                set: { store.leo.notes = $0 }
            ))
            .font(.body)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .scrollContentBackground(.hidden)
            .background(Color.secondary.opacity(0.05))
        }
    }
}

struct TermCardRow: View {
    let term: DetectedTerm
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(.tint)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(term.term)
                    .font(.subheadline.weight(.bold))
                Text(term.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }
}
