# 🎙️ MeetingCrew

회의 중 실시간으로 작동하는 3분할 AI 어시스턴트 앱.
3명의 AI 직원(Agent)이 각자 역할을 맡아 회의를 보조합니다.

**iOS 17+ / macOS 14+ · SwiftUI · Apple Speech Framework · Claude API**

---

## 👥 AI 직원 구성

| Agent | 역할 | 기능 |
|---|---|---|
| 🎙️ **TED** (Transcription & Executive Documentation) | 실시간 기록 & 요약 | Apple Speech Framework로 한국어 STT · 5분마다 Claude에게 누적 텍스트 요약 요청 · Action Item은 **볼드체**로 강조 |
| 📚 **LEO** (Language & Explanation Officer) | 용어 해석 + 메모 | 45초마다 transcript에서 전문용어 자동 감지 → Claude가 `{term, explanation}` JSON으로 응답 · 패널 하단은 자유 메모장 |
| ❓ **MAX** (Meeting Analyst & question eXpert) | 놓친 질문 제안 | 30초마다 "애매한 숫자·날짜·담당자·기한"을 Claude가 포착 → 체크 카드로 제시 · 완료/보류/삭제 액션 |

---

## 🖥️ UI 레이아웃

- **macOS**: 좌(TED) · 중(LEO) · 우(MAX) 3분할 `HStack` (`MainSplitView`)
- **iOS**: 하단 탭바 (`MainTabView`) — 🎙️ 기록 / 📚 용어·메모 / ❓ 질문
- 공통 `TopBar`: 🔴 녹음 상태 / 회의 제목 / 녹음·일시정지·종료 버튼 / 설정 · 히스토리

---

## 📁 프로젝트 구조

```
MeetingCrew/
├── App/
│   ├── MeetingCrewApp.swift       # @main 진입점 + ModelContainer
│   ├── ContentView.swift          # 플랫폼 분기 (macOS split / iOS tab)
│   └── MeetingSessionStore.swift  # 세 Agent 총괄 + 세션 상태 관리
├── Agents/
│   ├── TEDAgent.swift             # 음성인식 + 자동 요약
│   ├── LEOAgent.swift             # 용어 자동 감지
│   └── MAXAgent.swift              # 체크 질문 생성
├── Views/
│   ├── MainSplitView.swift        # macOS 3분할
│   ├── MainTabView.swift          # iOS 탭뷰
│   ├── TopBar.swift               # 공통 상단바
│   ├── TEDView.swift              # 왼쪽 패널
│   ├── LEOView.swift              # 가운데 패널
│   ├── MAXView.swift              # 오른쪽 패널
│   ├── SettingsView.swift         # API Key 입력
│   └── HistoryView.swift          # 저장된 회의록 목록/상세
├── Services/
│   ├── SpeechService.swift        # SFSpeechRecognizer 한국어 래퍼
│   └── ClaudeAPIService.swift     # Anthropic Messages API 래퍼
├── Models/
│   ├── MeetingSession.swift       # @Model PersistedMeetingSession
│   ├── TermCard.swift             # DetectedTerm 값 타입
│   └── QuestionCard.swift         # CheckQuestion 값 타입
└── Resources/
    ├── Info.plist                 # 마이크/음성인식 권한 설명
    ├── MeetingCrew.entitlements   # 샌드박스 권한
    └── Assets.xcassets
```

---

## 🚀 빌드 / 실행

### 사전 요구사항
- macOS 14 이상 · Xcode 15 이상
- Anthropic Console에서 발급한 Claude API Key

### 1. Xcode 프로젝트 생성

이 저장소에는 `.xcodeproj` 파일이 포함되지 않습니다 (XcodeGen으로 관리).
[XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 한 번만 생성해주세요:

```bash
brew install xcodegen
cd MeetingMind
xcodegen generate
open MeetingCrew.xcodeproj
```

### 2. (대안) 수동으로 Xcode 프로젝트 만들기

XcodeGen을 쓰지 않으려면:

1. Xcode → File → New → Project → **Multiplatform → App** 선택
2. Product Name: `MeetingCrew`, Interface: `SwiftUI`, Language: `Swift`
3. 생성 위치: `MeetingMind/` (이 저장소 루트)
4. 생성된 기본 `ContentView.swift`, `MeetingCrewApp.swift` 삭제
5. Finder에서 `MeetingCrew/` 폴더 (`App`, `Agents`, `Views`, `Services`, `Models`) 전체를 Xcode 좌측 Navigator로 드래그 → **Create groups** 선택, `MeetingCrew` 타겟 체크
6. `MeetingCrew/Resources/Info.plist` 사용하도록 Build Settings 에서 `Info.plist File` 경로 설정
7. Build Settings → `Swift Language Version` 5.9
8. Signing & Capabilities에서:
   - **macOS**: App Sandbox → Audio Input ✓, Outgoing Connections (Client) ✓
   - **iOS**: 팀 설정
9. Build & Run (⌘R)

### 3. 첫 실행

1. 앱 실행 → 우측 상단 ⚙️ 설정 아이콘 탭
2. **Claude API Key** 입력 (`sk-ant-...`)
3. **연결 테스트** 버튼으로 확인
4. **저장** → 메인으로 복귀
5. **녹음 시작** 버튼 → 최초 실행 시 마이크 · 음성 인식 권한 허용
6. 한국어로 회의 진행 → 좌(TED)에 실시간 텍스트, 45초~5분 단위로 LEO/MAX/요약 자동 갱신

---

## ⚙️ 기술 스택

- **플랫폼**: iOS 17+ / macOS 14+
- **UI**: SwiftUI (멀티플랫폼 단일 타겟)
- **STT**: `Speech.framework` (`SFSpeechRecognizer` + `AVAudioEngine`) — `ko-KR`
- **AI**: Anthropic Claude Messages API (`claude-sonnet-4-20250514`)
- **영속화**: SwiftData (`@Model PersistedMeetingSession`)
- **동시성**: Swift Concurrency (`async/await`, `@MainActor`, `Timer`)
- **권한**: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`

---

## 🔌 Claude API 호출 방식

세 Agent는 각자 다른 system prompt로 `ClaudeAPIService.sendMessage`를 호출합니다.

| Agent | 주기 | System Prompt 요지 | 응답 포맷 |
|---|---|---|---|
| TED  | 5분마다 + 수동 | "회의록을 3~6 bullet로 요약, Action Item은 **볼드**" | Markdown |
| LEO  | 45초마다 + 수동 | "전문용어 최대 5개, 순수 JSON 배열만" | `[{term, explanation}]` |
| MAX  | 30초마다 + 수동 | "놓친 숫자/날짜/담당자 최대 3개 질문" | `[String]` |

모든 호출은 토큰 낭비 방지를 위해:
- `transcript`가 최소 델타(LEO 60자 / MAX 80자) 이상 늘어났을 때만 실제 호출
- 이미 감지된 용어/질문은 system prompt에 포함해 중복 방지

---

## 📦 저장/불러오기

- **종료·저장** 버튼 → `MeetingSessionStore.makePersisted()`가 현재 상태를
  `PersistedMeetingSession`으로 직렬화하여 SwiftData `ModelContext`에 삽입
- **히스토리** 버튼(🕓) → `HistoryView`에서 최근 순 목록, 선택 시 상세 보기
- "현재 세션으로 불러오기" 버튼 → `store.load(session)`으로 화면 복원

---

## 🔒 보안 / 프라이버시

- 마이크 오디오는 **Apple Speech Framework 내부에서만 처리**되고 앱은 텍스트만 받습니다.
- Claude API 호출 시 **transcript 텍스트만** 전송되며, 오디오는 절대 업로드되지 않습니다.
- API Key는 기기의 `UserDefaults`에 저장됩니다 (운영 환경에서는 Keychain 사용 권장).
- macOS 빌드는 App Sandbox + Audio Input + Outgoing Network 권한만 요구합니다.

---

## ✅ 구현 우선순위 체크

- [x] 프로젝트 구조 + 기본 UI (macOS 3분할 / iOS 탭뷰)
- [x] Speech-to-Text (TED)
- [x] Claude API 연동 (TED 요약 / LEO 용어 / MAX 질문)
- [x] 회의록 저장·불러오기 (SwiftData)
- [x] 설정 화면 (API Key 입력 + 연결 테스트)

---

## 🗺️ 향후 개선 아이디어

- API Key를 Keychain으로 이전
- 스트리밍 응답 지원 (`anthropic-version` streaming)
- 실시간 요약: WhisperKit 등 온디바이스 STT 대안
- 회의 종료 후 Markdown/PDF 내보내기
- 탭·분할 이외 iPad 전용 Split 레이아웃
