//
//  TopBar.swift
//  MeetingCrew
//
//  상단 공통 바. 녹음 상태, 회의 제목, 녹음 제어 버튼, 설정/히스토리 진입.
//

import SwiftUI
import SwiftData

struct TopBar: View {
    @EnvironmentObject var store: MeetingSessionStore
    @Environment(\.modelContext) private var modelContext

    @Binding var showSettings: Bool
    @Binding var showHistory: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 상태 LED + 텍스트
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: statusColor.opacity(0.6), radius: 3)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 110, alignment: .leading)

            // 회의 제목
            TextField("회의 제목", text: $store.title)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Spacer(minLength: 8)

            // 녹음 제어
            if store.isRecording {
                if store.isPaused {
                    Button {
                        store.resume()
                    } label: {
                        Label("재개", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        store.pause()
                    } label: {
                        Label("일시정지", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    saveCurrentSession()
                    store.stop()
                } label: {
                    Label("종료·저장", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    store.start()
                } label: {
                    Label("녹음 시작", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            // 히스토리 / 설정
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("저장된 회의록")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .help("설정")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var statusText: String {
        if !store.isRecording { return "대기 중" }
        return store.isPaused ? "일시정지" : "녹음 중"
    }

    private var statusColor: Color {
        if !store.isRecording { return .gray }
        return store.isPaused ? .orange : .red
    }

    private func saveCurrentSession() {
        guard store.isRecording else { return }
        let persisted = store.makePersisted()
        modelContext.insert(persisted)
        try? modelContext.save()
    }
}
