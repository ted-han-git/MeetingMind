//
//  MainSplitView.swift
//  MeetingCrew
//
//  macOS 전용 3분할 메인 화면. 상단 TopBar + 좌(TED) / 중(LEO) / 우(MAX).
//

#if os(macOS)
import SwiftUI

struct MainSplitView: View {
    @EnvironmentObject var store: MeetingSessionStore
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showSettings: $showSettings, showHistory: $showHistory)
            Divider()
            HStack(spacing: 0) {
                TEDView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                LEOView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                MAXView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .alert("오류", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
#endif
