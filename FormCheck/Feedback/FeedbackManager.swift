import AVFoundation
import Combine
import UIKit

/// Voice + haptic callouts. AVSpeechSynthesizer is free and on-device.
/// Voice/sound preferences are read live from UserDefaults (see SettingsKeys).
final class FeedbackManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let warningHaptic = UINotificationFeedbackGenerator()
    private let repHaptic = UIImpactFeedbackGenerator(style: .heavy)

    private lazy var sadTrombone = Self.loadPlayer("sad-trombone")
    private lazy var victoryFanfare = Self.loadPlayer("victory")
    private lazy var ding = Self.loadPlayer("ding")

    private static func loadPlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private var voiceEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.voiceEnabled) as? Bool ?? true
    }
    private var robotStyle: Bool {
        (UserDefaults.standard.string(forKey: SettingsKeys.voiceStyle) ?? "robot") == "robot"
    }
    private var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.soundsEnabled) as? Bool ?? true
    }

    /// The most robotic voice this device offers, best first. Zarvox is the
    /// real robot voice; Eloquence voices are retro speech-synth; Fred is the
    /// classic '80s Mac. Availability varies by device/iOS, hence the chain.
    private static let robotVoice: AVSpeechSynthesisVoice? = {
        let preferred = [
            "com.apple.speech.synthesis.voice.Zarvox",
            "com.apple.eloquence.en-US.Rocko",
            "com.apple.eloquence.en-US.Eddy",
            "com.apple.speech.synthesis.voice.Fred",
        ]
        for identifier in preferred {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }
        return nil
    }()

    init() {
        // Mix over the user's gym music. Deliberately NOT .duckOthers: iOS
        // ducks for as long as the session is active, which would leave their
        // music quiet for the entire workout, not just during callouts.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private var lastLiveWarningTime: TimeInterval = -.infinity

    func repCompleted(_ score: RepScore, streak: Int) {
        repHaptic.impactOccurred()
        if let worstFault = score.faults.first {
            warningHaptic.notificationOccurred(.warning)
            speak("Rep \(score.repIndex). \(worstFault.cue)")
        } else if streak >= 3 {
            speak("Rep \(score.repIndex). \(streak) in a row.")
        } else {
            speak("Rep \(score.repIndex). Clean.")
        }
    }

    /// The hip just crossed parallel — instant positive confirmation.
    func depthReached() {
        repHaptic.impactOccurred(intensity: 0.7)
        guard soundsEnabled else { return }
        ding?.currentTime = 0
        ding?.play()
    }

    /// Mid-rep coaching cue, debounced on the capture clock so it doesn't nag every frame.
    func liveWarning(_ fault: FormFault, at time: TimeInterval) {
        guard time - lastLiveWarningTime > 3 else { return }
        lastLiveWarningTime = time
        warningHaptic.notificationOccurred(.warning)
        speak(fault.cue)
    }

    func placementReady() {
        speak("Perfect. Hold still.")
    }

    func setEnded(_ summary: SetSummary) {
        guard !summary.reps.isEmpty else { return }
        switch summary.grade {
        case "A":
            warningHaptic.notificationOccurred(.success)
            guard soundsEnabled else {
                speak("Set complete. Grade A. Perfect set.")
                return
            }
            victoryFanfare?.currentTime = 0
            victoryFanfare?.play()
            // Let the fanfare ring before the verdict.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                self?.speak("Grade A. Perfect set.")
            }
        case "F":
            warningHaptic.notificationOccurred(.error)
            guard soundsEnabled else {
                speak("Set complete. Grade F. We'll fix it.")
                return
            }
            sadTrombone?.currentTime = 0
            sadTrombone?.play()
            // Let the trombone land before the verdict.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) { [weak self] in
                self?.speak("Grade F. We'll fix it.")
            }
        default:
            speak("Set complete. Grade \(summary.grade).")
        }
    }

    /// Sample line for the settings screen's voice preview.
    func previewVoice() {
        speak("Rep 3. Clean.")
    }

    private func speak(_ text: String) {
        guard voiceEnabled else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        if robotStyle {
            if let voice = Self.robotVoice {
                utterance.voice = voice
            } else {
                // No synthetic voice installed — fake it with a flat, low pitch.
                utterance.pitchMultiplier = 0.6
            }
        }
        synthesizer.speak(utterance)
    }
}
