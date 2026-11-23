import SwiftUI

/// App flow:
///  onboarding → soft paywall → home.
///  Free users get one fully-featured scored set per day; right after it, the
///  paywall shows their own grade ("that set: B+ — now make every set count").
///  This replaces the old hard paywall, which sent most installs straight to
///  the delete button before they ever saw the skeleton work.
struct ContentView: View {
    @StateObject private var session = SessionViewModel()
    @StateObject private var store = EntitlementStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var paywall: PaywallContext?
    @State private var freeSetInProgress = false
    @State private var freeResult: (grade: String, score: Int)?
    @State private var freePassTick = 0

    #if DEBUG
    @AppStorage("debug.bypassPaywall") private var bypassPaywall = false
    private var isPro: Bool { store.isSubscribed || bypassPaywall }
    #else
    private var isPro: Bool { store.isSubscribed }
    #endif

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                    if !isPro { paywall = .onboarding }
                }
            } else if session.isActive {
                // A live set is never yanked away.
                LiveSessionView(session: session)
            } else if !store.entitlementsLoaded {
                ZStack {
                    GlowBackground()
                    ProgressView().tint(.lime)
                }
            } else {
                StartView(isPro: isPro,
                          freeSetAvailable: freePassTick >= 0 && FreePass.availableToday,
                          onStart: start,
                          onUpgrade: { paywall = .settings })
            }
        }
        .environmentObject(store)
        .tint(.lime)
        .preferredColorScheme(.dark) // brand is dark-only (Bones glows)
        .fullScreenCover(item: $paywall) { context in
            PaywallView(store: store, context: context) { paywall = nil }
        }
        .onChange(of: session.completedSet?.id) {
            guard freeSetInProgress, let summary = session.completedSet,
                  !summary.isFreestyle, !summary.reps.isEmpty else { return }
            FreePass.consume()
            freePassTick += 1
            freeResult = (summary.grade, summary.averageScore)
        }
        .onChange(of: session.isActive) {
            guard !session.isActive, freeSetInProgress else { return }
            freeSetInProgress = false
            if let r = freeResult, !isPro {
                freeResult = nil
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    paywall = .afterFreeSet(grade: r.grade, score: r.score)
                }
            }
        }
    }

    private func start(_ exercise: Exercise, _ mode: ViewMode, _ side: CameraSide) {
        if isPro {
            session.start(exercise: exercise, mode: mode, cameraSide: side)
        } else if FreePass.availableToday {
            freeSetInProgress = true
            session.start(exercise: exercise, mode: mode, cameraSide: side)
        } else {
            paywall = .freeSetUsed
        }
    }
}

#Preview {
    ContentView()
}
