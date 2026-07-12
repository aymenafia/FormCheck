import SwiftUI

@main
struct FormCheckApp: App {
    init() {
        InstallPing.fireIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
