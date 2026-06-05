import AVFoundation
import Foundation
import Speech

enum VoiceSearchError: LocalizedError {
    case speechRecognitionUnavailable
    case speechAuthorizationDenied
    case microphoneAuthorizationDenied
    case audioEngineUnavailable

    var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            "Speech recognition is unavailable on this device."
        case .speechAuthorizationDenied:
            "Speech recognition permission was denied."
        case .microphoneAuthorizationDenied:
            "Microphone permission was denied."
        case .audioEngineUnavailable:
            "Voice capture could not start."
        }
    }
}

@MainActor
protocol VoiceSearchServicing: AnyObject {
    var onTranscript: ((String, Bool) -> Void)? { get set }
    var onAvailabilityChange: ((Bool) -> Void)? { get set }

    func startTranscribing() async throws
    func stopTranscribing()
}

@MainActor
final class VoiceSearchService: NSObject, VoiceSearchServicing {
    var onTranscript: ((String, Bool) -> Void)?
    var onAvailabilityChange: ((Bool) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        recognizer?.delegate = self
    }

    func startTranscribing() async throws {
        guard let recognizer else {
            throw VoiceSearchError.speechRecognitionUnavailable
        }
        guard recognizer.isAvailable else {
            throw VoiceSearchError.speechRecognitionUnavailable
        }

        let speechAuthorized = await requestSpeechAuthorization()
        guard speechAuthorized else {
            throw VoiceSearchError.speechAuthorizationDenied
        }

        let micAuthorized = await requestMicrophoneAuthorization()
        guard micAuthorized else {
            throw VoiceSearchError.microphoneAuthorizationDenied
        }

        stopTranscribing()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.onTranscript?(transcript, result.isFinal)
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stopTranscribing()
                }
            }
        }
    }

    func stopTranscribing() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

extension VoiceSearchService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor [weak self] in
            self?.onAvailabilityChange?(available)
        }
    }
}
