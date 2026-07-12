import Combine
import Foundation
import SwiftUI

/// Wires the camera, rep state machine, rule engine, and feedback together.
/// All published state is mutated on the main queue (CameraManager delivers
/// poses on main).
final class SessionViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var latestPose: PoseFrame?
    @Published private(set) var phase: RepPhase = .calibrating
    @Published private(set) var repScores: [RepScore] = []
    @Published private(set) var cleanStreak = 0
    @Published private(set) var exercise: Exercise = .squat
    @Published private(set) var viewMode: ViewMode = .side
    @Published private(set) var cameraSide: CameraSide = .front
    @Published private(set) var liveWarning: FormFault?
    /// Increments the instant a squat hip crosses parallel — drives the
    /// "DEPTH ✓" flash. Fires once per rep.
    @Published private(set) var depthFlashCount = 0
    /// Recent bar-path samples for the velocity-colored trail.
    @Published private(set) var barTrail: [TrailSample] = []
    /// Best rep of this set, replayed as a translucent skeleton in real time
    /// while the next rep happens — race your own best rep.
    @Published private(set) var ghostPose: PoseFrame?
    @Published private(set) var placementComplete = false
    @Published private(set) var placementIssue: PlacementIssue? = .noBody
    @Published var completedSet: SetSummary?
    #if DEBUG
    @Published var debugEnabled = false
    @Published private(set) var debugText: String?
    #endif

    private var lastPoseDate: Date?

    let camera = CameraManager()
    private let stateMachine = RepStateMachine()
    private let ruleEngine = FormRuleEngine()
    private let feedback = FeedbackManager()
    private let placementChecker = PlacementChecker()
    private var placementStreak = 0
    private var repMetrics: [RepMetrics] = []
    private var depthFiredThisRep = false
    private var depthRawStreak = 0
    private var isEndingSet = false
    private var currentRepPoses: [(time: TimeInterval, pose: PoseFrame)] = []
    private var bestRepPoses: [(offset: TimeInterval, pose: PoseFrame)] = []
    private var bestRepScore = -1
    private var ghostStartTime: TimeInterval?
    private var ghostPending = false

    /// Consecutive good frames (~2/3 s at 30 fps) before the guide dismisses,
    /// so walking through the good zone doesn't count.
    private let placementStreakTarget = 20

    var repCount: Int { repScores.count }
    var lastScore: RepScore? { repScores.last }

    /// Skeleton goes red (and the skull goes 😵) when the last rep had faults.
    var lastRepFaulted: Bool {
        !(lastScore?.faults.isEmpty ?? true)
    }

    init() {
        camera.onPose = { [weak self] raw, smoothed in
            self?.handle(raw: raw, smoothed: smoothed)
        }
        stateMachine.onRepCompleted = { [weak self] metrics in
            guard let self else { return }
            let score = self.ruleEngine.score(metrics)
            self.cleanStreak = score.faults.isEmpty ? self.cleanStreak + 1 : 0
            self.repMetrics.append(metrics)
            self.repScores.append(score)
            self.feedback.repCompleted(score, streak: self.cleanStreak)

            // Keep this rep's pose sequence if it's the best so far — it
            // becomes the ghost the next rep races against.
            let repPoses: [(offset: TimeInterval, pose: PoseFrame)] = self.currentRepPoses.compactMap {
                $0.time >= metrics.startTime ? (offset: $0.time - metrics.startTime, pose: $0.pose) : nil
            }
            if score.score >= self.bestRepScore, repPoses.count >= 5 {
                self.bestRepScore = score.score
                self.bestRepPoses = repPoses
            }
            self.currentRepPoses = []
        }
        stateMachine.onPhaseChanged = { [weak self] newPhase in
            guard let self else { return }
            // Ghost starts only on a rep's FIRST descent (standing → descending);
            // a mid-rep bounce back into .descending must not restart it.
            let wasStanding = self.phase == .standing
            self.phase = newPhase
            switch newPhase {
            case .standing:
                self.depthFiredThisRep = false
                self.ghostStartTime = nil
                self.ghostPose = nil
            case .descending:
                if wasStanding { self.ghostPending = true }
            default:
                break
            }
        }
    }

    func start(exercise: Exercise, mode: ViewMode, cameraSide: CameraSide) {
        self.exercise = exercise
        self.cameraSide = cameraSide
        viewMode = exercise.supportsFrontView ? mode : .side
        stateMachine.exercise = exercise
        stateMachine.viewMode = viewMode
        repScores = []
        repMetrics = []
        cleanStreak = 0
        barTrail = []
        ghostPose = nil
        currentRepPoses = []
        bestRepPoses = []
        bestRepScore = -1
        ghostStartTime = nil
        ghostPending = false
        isEndingSet = false
        completedSet = nil
        cleanUpOldTempVideos()
        latestPose = nil
        liveWarning = nil
        placementComplete = false
        placementIssue = .noBody
        placementStreak = 0
        stateMachine.reset()
        camera.resetSmoothing()
        isActive = true
        camera.start(side: cameraSide)
        // Recording starts when placement completes — after that, orientation
        // is frozen and the file doesn't waste minutes of setup footage.
    }

    func skipPlacementGuide() {
        guard !placementComplete else { return }
        placementComplete = true
        camera.startRecording()
    }

    /// Abandon the set from the placement guide — no summary, no scoring.
    func cancelSession() {
        camera.stopRecording { _ in }
        camera.stop()
        completedSet = nil
        isActive = false
    }

    /// When tracking is lost, remove the frozen skeleton instead of leaving
    /// it painted over empty space. Called on a timer from the live view.
    func clearStalePoseIfNeeded() {
        guard isActive, latestPose != nil,
              let last = lastPoseDate, Date().timeIntervalSince(last) > 0.6 else { return }
        latestPose = nil
        liveWarning = nil
    }

    private func handle(raw: PoseFrame, smoothed: PoseFrame) {
        guard isActive, completedSet == nil else { return }
        latestPose = smoothed
        lastPoseDate = Date()

        // Hip calibration must not run while the user is still walking into
        // position, so frames stay with the placement checker until it passes.
        guard placementComplete else {
            updatePlacement(for: smoothed)
            return
        }

        // Buffer the rep's poses before processing so the completing frame
        // is included when the rep-completed callback slices the buffer.
        if phase == .descending || phase == .ascending, currentRepPoses.count < 400 {
            currentRepPoses.append((time: smoothed.timestamp, pose: smoothed))
        }

        stateMachine.process(smoothed)
        updateLiveWarning(for: smoothed)
        // Raw pose for the depth trigger: the smoothing filter lags at the
        // turnaround, and this moment lives or dies on latency.
        updateDepthFlash(for: raw)
        updateBarTrail(with: smoothed)
        updateGhost(with: smoothed)
        #if DEBUG
        if debugEnabled { updateDebugText(for: smoothed) }
        #endif
    }

    private func updateBarTrail(with frame: PoseFrame) {
        guard let point = BarTrail.barPoint(in: frame, exercise: exercise) else { return }
        let speed = BarTrail.speed(from: barTrail.last, to: point, at: frame.timestamp,
                                   aspect: frame.imageAspect, bodySpan: frame.bodySpan)
        barTrail.append(TrailSample(point: point, time: frame.timestamp, speed: speed))
        let cutoff = frame.timestamp - BarTrail.window
        barTrail.removeAll { $0.time < cutoff }
    }

    /// Replays the best rep's poses on the wall clock, starting the moment
    /// the current rep starts descending.
    private func updateGhost(with frame: PoseFrame) {
        if ghostPending {
            ghostPending = false
            ghostStartTime = bestRepPoses.isEmpty ? nil : frame.timestamp
        }
        guard let start = ghostStartTime, let lastOffset = bestRepPoses.last?.offset else { return }
        let elapsed = frame.timestamp - start
        if elapsed > lastOffset + 0.25 {
            ghostPose = nil
            return
        }
        ghostPose = (bestRepPoses.last(where: { $0.offset <= elapsed }) ?? bestRepPoses.first)?.pose
    }

    #if DEBUG
    private func updateDebugText(for frame: PoseFrame) {
        var lines = [
            "\(exercise.rawValue) · \(viewMode.rawValue) · \(phase.rawValue) · reps \(repCount)",
            stateMachine.debugSnapshot,
            "joints \(frame.joints.count)",
        ]
        if let y = (exercise.tracksWrists ? frame.wristCenter : frame.hipCenter)?.y {
            lines[2] += String(format: "  y %.3f", y)
        }
        if let lean = frame.torsoLeanDegrees {
            lines.append(String(format: "lean %.0f°", lean))
        }
        if viewMode == .front, let ratio = frame.kneeSeparationRatio {
            lines.append(String(format: "kneeSep %.2f", ratio))
        }
        if exercise == .bench, let elbow = frame.maxElbowExtensionDegrees {
            lines.append(String(format: "elbow %.0f°", elbow))
        }
        debugText = lines.joined(separator: "\n")
    }
    #endif

    private func updatePlacement(for frame: PoseFrame) {
        let issue = placementChecker.check(frame, exercise: exercise, mode: viewMode)
        placementIssue = issue
        guard issue == nil else {
            placementStreak = 0
            return
        }
        placementStreak += 1
        if placementStreak >= placementStreakTarget {
            placementComplete = true
            camera.startRecording()
            feedback.placementReady()
        }
    }

    /// Mid-rep coaching is the demo moment: the fault is called out while
    /// it's still fixable, with the offending joints ringed on screen.
    private func updateLiveWarning(for frame: PoseFrame) {
        guard phase == .descending || phase == .ascending,
              let fault = detectLiveFault(in: frame) else {
            if liveWarning != nil { liveWarning = nil }
            return
        }
        if liveWarning != fault { liveWarning = fault }
        feedback.liveWarning(fault, at: frame.timestamp)
    }

    /// Live thresholds sit slightly past the scoring thresholds so the banner
    /// only fires when the fault is unambiguous — a nagging coach gets muted.
    private func detectLiveFault(in frame: PoseFrame) -> FormFault? {
        switch (exercise, viewMode) {
        case (.squat, .front):
            if let ratio = frame.kneeSeparationRatio, ratio < 0.8 {
                return .kneeValgus
            }
        case (.squat, .side):
            if let lean = frame.torsoLeanDegrees, lean > 60 {
                return .excessiveLean
            }
        case (.deadlift, _):
            if phase == .ascending,
               let wrist = frame.wristCenter, let ankle = frame.ankleCenter,
               let span = stateMachine.calibratedBodySpan,
               abs(wrist.x - ankle.x) * frame.imageAspect / span > 0.13 {
                return .barDrift
            }
        default:
            break
        }
        return nil
    }

    /// The positive live moment: the instant the hip crosses parallel,
    /// flash DEPTH ✓ with a ding — cause and effect inside one rep.
    /// Runs on the raw pose for minimal latency; two consecutive raw frames
    /// (~33 ms) must agree so a single jittery frame can't fire it.
    private func updateDepthFlash(for frame: PoseFrame) {
        guard exercise == .squat, viewMode == .side, !depthFiredThisRep,
              phase == .descending || phase == .ascending,
              let hipY = frame.hipCenter?.y,
              let kneeY = frame.mostConfidentKneeY,
              hipY >= kneeY - 0.02 else {
            depthRawStreak = 0
            return
        }
        depthRawStreak += 1
        guard depthRawStreak >= 2 else { return }
        depthFiredThisRep = true
        depthFlashCount += 1
        feedback.depthReached()
    }

    func endSet() {
        // Idempotence: a double-tap must not add the set to history twice or
        // clobber the real summary with a recording-less one.
        guard isActive, !isEndingSet else { return }
        isEndingSet = true
        camera.stopRecording { [weak self] recording in
            guard let self else { return }
            let summary = SetSummary(clips: self.makeClips(recording: recording),
                                     recording: recording)
            self.completedSet = summary
            self.feedback.setEnded(summary)
            if !summary.reps.isEmpty {
                HistoryStore.shared.add(SetRecord(summary: summary,
                                                  exercise: self.exercise,
                                                  viewMode: self.viewMode))
            }
        }
        camera.stop()
    }

    /// Rebases each rep's capture-clock times into the recording timeline,
    /// padded so replays show the setup and lockout around the rep.
    private func makeClips(recording: SessionRecording?) -> [RepClip] {
        // Running clean-streak value at each rep, so exports can badge it.
        var run = 0
        let streaks = repScores.map { score in
            run = score.faults.isEmpty ? run + 1 : 0
            return run
        }
        return zip(zip(repMetrics, repScores), streaks).map { pair, streak in
            let (metrics, score) = pair
            guard let recording else { return RepClip(score: score, streak: streak, start: 0, end: 0) }
            let offset = recording.sourceStartTime
            return RepClip(score: score,
                           streak: streak,
                           start: max(0, metrics.startTime - offset - 0.5),
                           end: metrics.endTime - offset + 0.3)
        }
    }

    func finishSession() {
        // The set recording is only needed for exports from the summary sheet.
        if let url = completedSet?.recording?.url {
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: url)
            }
        }
        completedSet = nil
        isActive = false
    }

    /// Sweep set recordings and exported clips from previous sessions out of
    /// tmp — the OS only purges it opportunistically, and 720p video adds up.
    private func cleanUpOldTempVideos() {
        DispatchQueue.global(qos: .utility).async {
            let tmp = FileManager.default.temporaryDirectory
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: tmp, includingPropertiesForKeys: nil) else { return }
            for url in files {
                let name = url.lastPathComponent
                if name.hasPrefix("formcheck-set-") || name.hasPrefix("FormCheck-rep") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}
