import SwiftUI

/// Pre-set placement guide: a ghost silhouette showing where to stand, plus
/// one live correction at a time. Turns green and auto-dismisses (via the
/// session view model) once placement holds steady.
struct GhostGuideView: View {
    let exercise: Exercise
    let mode: ViewMode
    let issue: PlacementIssue?
    let onSkip: () -> Void
    let onCancel: () -> Void

    private var isGood: Bool { issue == nil }
    private var isLying: Bool { exercise.tracksWrists }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                // The target zone: fill the ghost — upright, or rotated flat
                // for bench.
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(height: isLying ? geo.size.width * 0.8 : geo.size.height * 0.62)
                    .rotationEffect(isLying ? .degrees(90) : .zero)
                    .foregroundStyle(isGood ? Color.green.opacity(0.55) : Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 16) {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal)

                    instructionCard

                    Spacer()

                    Button("Skip guide", action: onSkip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
            }
        }
        .animation(.snappy, value: issue)
    }

    private var instructionCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: issue?.systemImage ?? "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isGood ? .green : .orange)
                Text(issue?.message ?? "Perfect — hold still…")
                    .font(.title3.weight(.bold))
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 24)
    }

    private var hint: String {
        if isLying {
            return "Phone sideways at chest height · side-on to the bench · ~2.5 m away"
        }
        switch mode {
        case .side: return "Phone at knee height · side-on · ~2.5 m away"
        case .front: return "Phone at knee height · facing you · ~2.5 m away"
        }
    }
}

#Preview {
    GhostGuideView(exercise: .squat, mode: .side, issue: .tooFar, onSkip: {}, onCancel: {})
        .preferredColorScheme(.dark)
        .background(.gray)
}
