//
//  MainTabView.swift
//  MeetingCrew
//
//  iOS 전용 탭 전환 메인 화면. 상단 TopBar + 하단 탭 (TED / LEO / MAX).
//

#if os(iOS)
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: MeetingSessionStore
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var selection: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showSettings: $showSettings, showHistory: $showHistory)
            TabView(selection: $selection) {
                TEDView()
                    .tabItem {
                        Label("기록", systemImage: "mic.fill")
                    }
                    .tag(0)

                LEOView()
                    .tabItem {
                        Label("용어·메모", systemImage: "book.fill")
                    }
                    .tag(1)

                MAXView()
                    .tabItem {
                        Label("질문", systemImage: "questionmark.circle.fill")
                    }
                    .tag(2)
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
