import SwiftUI

struct LiveSessionView: View {
    @ObservedObject var session: SessionViewModel
    @ObservedObject var camera: CameraManager

    init(session: SessionViewModel) {
        self.session = session
        self.camera = session.camera
    }

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session, rotationAngle: camera.videoRotationAngle)
                .ignoresSafeArea()

            SkeletonOverlayView(pose: session.latestPose,
                                faulted: session.lastRepFaulted,
                                highlight: session.liveWarning?.highlightJoints ?? [],
                                ghost: session.ghostPose,
                                trail: session.barTrail)
                .ignoresSafeArea()

            // Whole-screen red glow while a live fault is happening.
            if session.liveWarning != nil {
                RoundedRectangle(cornerRadius: 44)
                    .strokeBorder(Color.red.opacity(0.55), lineWidth: 16)
                    .blur(radius: 12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            RepEffectsView(pose: session.latestPose,
                           exercise: session.exercise,
                           cleanRep: !session.lastRepFaulted,
                           streak: session.cleanStreak,
                           trigger: session.repCount)

            if session.placementComplete {
                HUDView(session: session)
                    .transition(.opacity)
            } else if !camera.permissionDenied {
                GhostGuideView(
                    exercise: session.exercise,
                    mode: session.viewMode,
                    issue: session.placementIssue,
                    onSkip: { session.skipPlacementGuide() },
                    onCancel: { session.cancelSession() }
                )
                .transition(.opacity)
            }

            if camera.permissionDenied {
                PermissionDeniedView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.placementComplete)
        .sheet(item: $session.completedSet) { summary in
            SetSummaryView(summary: summary) {
                session.finishSession()
            }
            .interactiveDismissDisabled()
        }
        // Free rotation while positioning the phone; locked once the set
        // starts, since calibration and the recording assume one orientation.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if !session.placementComplete {
                camera.updateRotationAngle()
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            session.clearStalePoseIfNeeded()
        }
        .animation(.easeInOut(duration: 0.2), value: session.liveWarning != nil)
    }
}

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
            Text("Camera access is required")
                .font(.headline)
            Text("Enable it in Settings → FormCheck to analyze your form.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(40)
    }
}
