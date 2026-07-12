import SwiftUI

/// One-shot confetti rain for A-grade sets. Self-contained: spawns on appear,
/// falls once (~3 s), never blocks touches.
struct ConfettiView: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat          // horizontal position, fraction of width
        let delay: Double
        let fallDuration: Double
        let size: CGFloat
        let color: Color
        let spin: Double        // total rotation over the fall, degrees
        let sway: CGFloat       // horizontal drift during the fall, points
        let isRound: Bool
    }

    private static let colors: [Color] = [.green, .yellow, .orange, .pink, .blue, .purple, .mint]

    @State private var particles: [Particle] = []
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    piece(for: particle)
                        .position(x: particle.x * geo.size.width, y: -30)
                        .offset(x: falling ? particle.sway : 0,
                                y: falling ? geo.size.height + 80 : 0)
                        .rotationEffect(.degrees(falling ? particle.spin : 0))
                        .animation(
                            .easeIn(duration: particle.fallDuration).delay(particle.delay),
                            value: falling
                        )
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<70).map { _ in
                Particle(
                    x: CGFloat.random(in: 0...1),
                    delay: Double.random(in: 0...0.8),
                    fallDuration: Double.random(in: 1.8...3.2),
                    size: CGFloat.random(in: 7...13),
                    color: Self.colors.randomElement() ?? .green,
                    spin: Double.random(in: 360...1080) * (Bool.random() ? 1 : -1),
                    sway: CGFloat.random(in: -70...70),
                    isRound: Bool.random()
                )
            }
            falling = true
        }
    }

    @ViewBuilder
    private func piece(for particle: Particle) -> some View {
        if particle.isRound {
            Circle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size)
        } else {
            Rectangle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size * 0.55)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiView()
    }
}
