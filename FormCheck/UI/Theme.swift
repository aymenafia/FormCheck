import SwiftUI

// MARK: - Palette

extension Color {
    /// Brand lime — matches Bones' glowing eyes and whistle.
    static let lime = Color(red: 0.616, green: 1.0, blue: 0.235)
    static let limeDeep = Color(red: 0.36, green: 0.78, blue: 0.10)
    static let ink = Color(red: 0.035, green: 0.043, blue: 0.035)
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.09)
}

// MARK: - Backgrounds

/// Near-black canvas with a soft lime glow — the app's signature backdrop.
struct GlowBackground: View {
    var glowAt: UnitPoint = .top
    var intensity: Double = 0.28

    var body: some View {
        ZStack {
            Color.ink
            RadialGradient(colors: [Color.lime.opacity(intensity), .clear],
                           center: glowAt, startRadius: 10, endRadius: 420)
            LinearGradient(colors: [.clear, Color.black.opacity(0.6)],
                           startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

struct LimeButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [.lime, .limeDeep], startPoint: .top, endPoint: .bottom))
                    .opacity(enabled ? 1 : 0.4)
            )
            .shadow(color: .lime.opacity(enabled ? 0.45 : 0), radius: configuration.isPressed ? 6 : 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().strokeBorder(Color.white.opacity(0.15)))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Cards

struct CardModifier: ViewModifier {
    var highlighted = false
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(highlighted ? Color.lime.opacity(0.12) : Color.card))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(highlighted ? Color.lime : Color.cardStroke, lineWidth: highlighted ? 2 : 1))
    }
}

extension View {
    func card(highlighted: Bool = false) -> some View { modifier(CardModifier(highlighted: highlighted)) }
}

// MARK: - Mascot

/// Bones, the FormCheck coach. Gently bobs so screens feel alive.
struct Mascot: View {
    enum Pose: String {
        case wave = "bones-wave"
        case squat = "bones-squat"
        case win = "bones-win"
        case thumbs = "bones-thumbs"
        case think = "bones-think"
    }

    let pose: Pose
    var height: CGFloat = 260
    var animated = true

    @State private var bob = false

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .shadow(color: .lime.opacity(0.35), radius: 30)
            .offset(y: animated && bob ? -6 : 0)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

/// Speech-bubble the mascot "says".
struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
