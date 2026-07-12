import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionViewModel()
    @StateObject private var store = EntitlementStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(SettingsKeys.appearance) private var appearance = "dark"

    #if DEBUG
    // Dev-only paywall bypass. The property and its key exist only in Debug,
    // so nothing about it — not even the string — is in the shipped binary.
    @AppStorage("debug.bypassPaywall") private var bypassPaywall = false
    private var paywallBypassed: Bool { bypassPaywall }
    #else
    private var paywallBypassed: Bool { false }
    #endif

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView { hasCompletedOnboarding = true }
            } else if session.isActive {
                // A live set is never yanked away — if entitlement lapses
                // mid-set, the paywall waits until the set ends.
                LiveSessionView(session: session)
            } else if !store.entitlementsLoaded {
                // Brief moment on cold launch — prevents flashing the paywall
                // at paying subscribers before StoreKit answers.
                ProgressView()
            } else if !store.isSubscribed && !paywallBypassed {
                PaywallView(store: store)
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
