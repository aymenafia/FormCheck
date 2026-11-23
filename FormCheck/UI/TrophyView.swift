import SwiftUI

/// Trophy case: every badge, earned ones glowing, locked ones with the goal.
struct TrophyView: View {
    @ObservedObject private var history = HistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    private var unlocked: Set<Badge> { Achievements.unlocked(in: history.records) }

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground(glowAt: .top, intensity: 0.22)
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 14) {
                            Mascot(pose: unlocked.count >= 6 ? .win : .thumbs, height: 120)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(unlocked.count) of \(Badge.allCases.count)")
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.lime)
                                Text("trophies earned").font(.headline)
                                ProgressView(value: Double(unlocked.count), total: Double(Badge.allCases.count))
                                    .tint(.lime)
                            }
                        }
                        .padding(16)
                        .card()

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 18) {
                            ForEach(Badge.allCases) { badge in
                                let has = unlocked.contains(badge)
                                VStack(spacing: 8) {
                                    BadgeIcon(badge: badge, unlocked: has, size: 70)
                                    Text(badge.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(has ? .primary : .secondary)
                                    Text(badge.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2, reservesSpace: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(16)
                        .card()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Trophies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { TrophyView() }
