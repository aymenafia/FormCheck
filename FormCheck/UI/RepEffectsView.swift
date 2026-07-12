import SwiftUI

/// One-shot effects when a rep completes: 💨 puffs at the feet (or at the
/// bar/wrists for bench) on every lockout, plus a 💪 burst at the shoulders
/// when the rep was clean. `trigger` is the rep count; each increment spawns
/// effects at the current joint positions, which drift and fade.
struct RepEffectsView: View {
    let pose: PoseFrame?
    let exercise: Exercise
    let cleanRep: Bool
    let streak: Int
    let trigger: Int

    fileprivate struct Effect: Identifiable {
        let id = UUID()
        let emoji: String
        let point: CGPoint
        let drift: CGFloat
        let rise: CGFloat
        let size: CGFloat
        let mirrored: Bool
    }

    @State private var effects: [Effect] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(effects) { effect in
                    EffectEmoji(effect: effect)
                }
            }
            .onChange(of: trigger) {
                spawn(in: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func spawn(in size: CGSize) {
        guard trigger > 0, let pose else { return }
        var spawned: [Effect] = []

        let puffJoints: [(Joint, CGFloat)] = exercise.tracksWrists
            ? [(.leftWrist, -28), (.rightWrist, 28)]
            : [(.leftAnkle, -28), (.rightAnkle, 28)]
        for (joint, drift) in puffJoints {
            guard let point = viewPoint(of: joint, in: pose, size: size) else { continue }
            spawned.append(Effect(emoji: "💨", point: point, drift: drift,
                                  rise: -14, size: 38, mirrored: false))
        }

        if cleanRep {
            for (joint, drift) in [(Joint.leftShoulder, CGFloat(-34)), (.rightShoulder, 34)] {
                guard let point = viewPoint(of: joint, in: pose, size: size) else { continue }
                spawned.append(Effect(emoji: "💪", point: point, drift: drift,
                                      rise: -44, size: 44, mirrored: drift < 0))
            }
            if streak >= 3, let head = viewPoint(of: .nose, in: pose, size: size)
                ?? viewPoint(of: .neck, in: pose, size: size) {
                spawned.append(Effect(emoji: "🔥", point: head, drift: 0,
                                      rise: -80, size: 50, mirrored: false))
            }
        }

        guard !spawned.isEmpty else { return }
        effects.append(contentsOf: spawned)

        let ids = Set(spawned.map(\.id))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            effects.removeAll { ids.contains($0.id) }
        }
    }

    private func viewPoint(of joint: Joint, in pose: PoseFrame, size: CGSize) -> CGPoint? {
        guard let point = pose.joints[joint],
              point.confidence >= PoseFrame.minConfidence else { return nil }
        return OverlayMapping.viewPoint(point.location, imageAspect: pose.imageAspect, in: size)
    }
}

private struct EffectEmoji: View {
    let effect: RepEffectsView.Effect

    @State private var animating = false

    var body: some View {
        Text(effect.emoji)
            .font(.system(size: effect.size))
            .scaleEffect(x: effect.mirrored ? -1 : 1)
            .scaleEffect(animating ? 1.5 : 0.3)
            .opacity(animating ? 0 : 1)
            .position(effect.point)
            .offset(x: animating ? effect.drift : 0, y: animating ? effect.rise : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { animating = true }
            }
    }
}
