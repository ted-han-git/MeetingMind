//
//  SettingsView.swift
//  MeetingCrew
//
//  Claude API Key 입력 화면.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ClaudeAPIService.shared.apiKey
    @State private var testing: Bool = false
    @State private var testResult: String? = nil
    @State private var testError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("설정")
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Claude API Key", systemImage: "key.fill")
                    .font(.headline)
                SecureField("sk-ant-api03-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    #endif
                Text("키는 이 기기의 UserDefaults에만 저장되며 외부로 전송되지 않습니다.\nAnthropic Console(console.anthropic.com)에서 발급받을 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("사용 모델", systemImage: "cpu.fill")
                    .font(.headline)
                Text(ClaudeAPIService.shared.model)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    save()
                } label: {
                    Label("저장", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    Task { await testConnection() }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("연결 테스트", systemImage: "bolt.fill")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || testing)

                Spacer()
            }

            if let result = testResult {
                Text("✅ \(result)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let error = testError {
                Text("❌ \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 380)
    }

    private func save() {
        ClaudeAPIService.shared.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }

    private func testConnection() async {
        testing = true
        testResult = nil
        testError = nil
        defer { testing = false }

        // 임시 적용 후 테스트
        let previous = ClaudeAPIService.shared.apiKey
        ClaudeAPIService.shared.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let hello = try await ClaudeAPIService.shared.sendMessage(
                system: "당신은 친절한 비서입니다. 한국어로 딱 한 문장만 응답하세요.",
                userText: "안녕? 한 문장으로 네가 누구인지 말해줘.",
                maxTokens: 100
            )
            testResult = "연결 성공: \(hello.prefix(80))"
        } catch {
            testError = error.localizedDescription
            // 실패 시 기존 키 복원
            ClaudeAPIService.shared.apiKey = previous
        }
    }
}
