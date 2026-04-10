//
//  MeetingCrewApp.swift
//  MeetingCrew
//
//  3명의 AI 직원(TED, LEO, MAX)이 회의를 돕는 iOS/macOS 앱의 진입점.
//

import SwiftUI
import SwiftData

@main
struct MeetingCrewApp: App {
    @StateObject private var store = MeetingSessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .modelContainer(for: [PersistedMeetingSession.self])

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
