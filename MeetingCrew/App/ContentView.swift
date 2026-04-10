//
//  ContentView.swift
//  MeetingCrew
//
//  플랫폼에 따라 3분할(macOS) 또는 탭뷰(iOS) 레이아웃을 선택.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        MainSplitView()
            .frame(minWidth: 1100, minHeight: 680)
        #else
        MainTabView()
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(MeetingSessionStore())
}
