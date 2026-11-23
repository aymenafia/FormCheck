import SwiftUI
import UIKit

/// Story-sized (9:16) grade card — the "post your score" moment. Every share
/// is a free ad: Bones, the grade, and the app name.
struct ShareCardView: View {
    let exercise: String
    let grade: String
    let score: Int
    let reps: Int
    let cleanReps: Int
    let bestStreak: Int
    var personalBest = false

    var body: some View {
        ZStack {
            Color.ink
            RadialGradient(colors: [Color.lime.opacity(0.45), .clear], center: .init(x: 0.5, y: 0.38),
                           startRadius: 10, endRadius: 330)
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("FORMCHECK").kerning(4)
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.lime)
                .padding(.top, 34)

                Text(exercise.uppercased() + " FORM CHECK")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)

                ZStack {
                    Mascot(pose: Self.pose(for: grade), height: 250, animated: false)
                        .offset(x: 62, y: 12)
                    Text(grade)
                        .font(.system(size: 190, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, .lime], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .lime.opacity(0.6), radius: 24)
                        .offset(x: -70)
                }
                .frame(height: 280)
                .padding(.top, 8)

                if personalBest {
                    Text("NEW PERSONAL BEST")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .kerning(1.5)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.lime, in: Capsule())
                        .foregroundStyle(.black)
                        .padding(.bottom, 10)
                }

                Text("Form score \(score)/100")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    stat("\(reps)", "reps")
                    stat("\(cleanReps)", "clean")
                    stat("\(bestStreak)", "best streak")
                }
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Text("Checked live by Bones, my AI form coach")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("FormCheck · on the App Store")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 30)
            }
        }
        .frame(width: 360, height: 640)
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(Color.lime)
            Text(l).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    static func pose(for grade: String) -> Mascot.Pose {
        switch grade {
        case "A": return .win
        case "B": return .thumbs
        case "C": return .squat
        default: return .think
        }
    }

    /// 1080×1920 PNG-ready image for Instagram/TikTok stories.
    @MainActor func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview {
    ShareCardView(exercise: "Squat", grade: "A", score: 93, reps: 8, cleanReps: 7, bestStreak: 6, personalBest: true)
}
