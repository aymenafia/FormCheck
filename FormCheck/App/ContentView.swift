import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionViewModel()
    @StateObject private var store = EntitlementStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("debug.bypassPaywall") private var bypassPaywall = false
    @AppStorage(SettingsKeys.appearance) private var appearance = "dark"

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView { hasCompletedOnboarding = true }
            } else if !store.isSubscribed && !bypassPaywall {
                PaywallView(store: store)
            } else if session.isActive {
                LiveSessionView(session: session)
            } else {
                StartView { exercise, mode, side in
                    session.start(exercise: exercise, mode: mode, cameraSide: side)
                }
            }
        }
        .preferredColorScheme(Appearance.colorScheme(for: appearance))
    }
}

#Preview {
    ContentView()
}
