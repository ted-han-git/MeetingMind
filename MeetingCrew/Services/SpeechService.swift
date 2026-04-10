//
//  SpeechService.swift
//  MeetingCrew
//
//  Apple Speech Framework 기반 한국어 실시간 음성 인식 서비스.
//  AVAudioEngine으로 마이크 버퍼를 받아 SFSpeechAudioBufferRecognitionRequest에 전달.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechService: ObservableObject {

    // MARK: - Published 상태

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// 누적된 텍스트의 앞쪽 부분(정지 후 재개 시 이어붙이기 위해).
    private var committedPrefix: String = ""

    // MARK: - 권한

    func requestAuthorization() async {
        // 음성 인식 권한
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }

        // 마이크 권한 (iOS 한정)
        #if os(iOS)
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        } else {
            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
        #else
        // macOS는 Info.plist의 NSMicrophoneUsageDescription만 있으면
        // 첫 접근 시 시스템이 자동으로 권한 대화상자를 띄운다.
        let micGranted = true
        #endif

        self.isAuthorized = (speechStatus == .authorized) && micGranted
        if !self.isAuthorized {
            self.errorMessage = "마이크 또는 음성 인식 권한이 거부되었습니다. 시스템 설정에서 허용해주세요."
        } else {
            self.errorMessage = nil
        }
    }

    // MARK: - 녹음 제어

    /// 새 세션 시작 (committedPrefix 초기화 없음 — 상위에서 reset()로 관리).
    func start() throws {
        guard isAuthorized else {
            throw NSError(domain: "SpeechService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "권한이 없어 시작할 수 없습니다."])
        }
        guard !audioEngine.isRunning else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, macOS 13.0, *) {
            request.addsPunctuation = true
        }
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        guard let recognizer, recognizer.isAvailable else {
            stopEngine()
            throw NSError(domain: "SpeechService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "한국어 음성 인식기를 사용할 수 없습니다."])
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    let live = result.bestTranscription.formattedString
                    if self.committedPrefix.isEmpty {
                        self.transcript = live
                    } else {
                        self.transcript = self.committedPrefix + " " + live
                    }
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    // 현재까지의 내용을 committedPrefix에 누적
                    if !self.transcript.isEmpty {
                        self.committedPrefix = self.transcript
                    }
                    self.stopEngine()
                }
            }
        }

        isRecording = true
    }

    /// 완전 중지 (세션 종료).
    func stop() {
        stopEngine()
        committedPrefix = ""
    }

    /// 일시정지: 엔진만 멈추고 committedPrefix에 현재까지 내용을 고정.
    func pause() {
        if !transcript.isEmpty {
            committedPrefix = transcript
        }
        stopEngine()
    }

    /// 재개: 새 recognition 세션을 시작.
    func resume() throws {
        try start()
    }

    func reset() {
        stopEngine()
        transcript = ""
        committedPrefix = ""
        errorMessage = nil
    }

    // MARK: - Internal

    private func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
