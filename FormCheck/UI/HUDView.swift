import SwiftUI

struct HUDView: View {
    @ObservedObject var session: SessionViewModel
    @State private var showDepthFlash = false

    var body: some View {
        VStack {
            HStack {
                Text(session.phase.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                Spacer()

                #if DEBUG
                Button {
                    session.debugEnabled.toggle()
                } label: {
                    Image(systemName: "ant.fill")
                        .foregroundStyle(session.debugEnabled ? .green : .secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                #endif

                Button {
                    session.endSet()
                } label: {
                    Text("End Set")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)

            #if DEBUG
            if session.debugEnabled, let debug = session.debugText {
                Text(debug)
                    .font(.caption.monospaced())
                    .padding(10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            #endif

            if let warning = session.liveWarning {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                    Text(warning.rawValue.uppercased())
                        .font(.title3.weight(.black))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.92), in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: .red.opacity(0.7), radius: 12)
                .padding(.top, 14)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(session.repCount)")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: session.repCount)
                Text("REPS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))

                if session.cleanStreak >= 3 {
                    Text("🔥 \(session.cleanStreak) in a row")
                        .font(.headline.weight(.black))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.top, 6)
                        .transition(.scale.combined(with: .opacity))
                }

                if let last = session.lastScore {
                    LastRepBadge(score: last)
                        .padding(.top, 10)
                }
            }
            .padding(.bottom, 36)
        }
        .animation(.snappy, value: session.liveWarning)
        .animation(.snappy, value: session.cleanStreak)
        .overlay {
            if showDepthFlash {
                Text("DEPTH ✓")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .onChange(of: session.depthFlashCount) {
            withAnimation(.spring(duration: 0.25)) { showDepthFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) { showDepthFlash = false }
            }
        }
    }
}

private struct LastRepBadge: View {
    let score: RepScore

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: score.faults.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(score.faults.isEmpty ? "Clean rep — \(score.score)" : "Rep \(score.repIndex): \(score.score)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(score.faults.isEmpty ? .green : .orange)

            ForEach(score.faults) { fault in
                Text(fault.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
