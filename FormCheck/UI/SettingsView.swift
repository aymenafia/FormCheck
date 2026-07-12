import SwiftUI

enum SettingsKeys {
    static let voiceEnabled = "settings.voiceEnabled"
    static let voiceStyle = "settings.voiceStyle"   // "robot" | "normal"
    static let soundsEnabled = "settings.soundsEnabled"
    static let appearance = "settings.appearance"   // "dark" | "light" | "system"
}

enum Appearance {
    /// Maps the stored preference to SwiftUI's scheme (nil = follow system).
    static func colorScheme(for stored: String) -> ColorScheme? {
        switch stored {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKeys.voiceEnabled) private var voiceEnabled = true
    @AppStorage(SettingsKeys.voiceStyle) private var voiceStyle = "robot"
    @AppStorage(SettingsKeys.soundsEnabled) private var soundsEnabled = true
    @AppStorage(SettingsKeys.appearance) private var appearance = "dark"

    @Environment(\.dismiss) private var dismiss
    @StateObject private var previewFeedback = FeedbackManager()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Voice callouts", isOn: $voiceEnabled)
                    Picker("Voice style", selection: $voiceStyle) {
                        Text("Robot 🤖").tag("robot")
                        Text("Normal").tag("normal")
                    }
                    .disabled(!voiceEnabled)
                } header: {
                    Text("Coach Voice")
                } footer: {
                    Text("Rep counts, form cues, and streaks — spoken while you lift.")
                }

                Section {
                    Toggle("Grade sounds", isOn: $soundsEnabled)
                } footer: {
                    Text("Victory fanfare on an A set, sad trombone on an F.")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Link("Manage Subscription",
                         destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Link("Privacy Policy",
                         destination: URL(string: "https://github.com/aymenafia/FormCheck/blob/main/PRIVACY.md")!)
                    Link("Terms of Use",
                         destination: URL(string: "https://github.com/aymenafia/FormCheck/blob/main/TERMS.md")!)
                }

                Section {
                } footer: {
                    Text("FormCheck \(appVersion) · All processing happens on-device. Your video never leaves your phone.")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: voiceStyle) {
                previewFeedback.previewVoice()
            }
            .onChange(of: voiceEnabled) {
                if voiceEnabled { previewFeedback.previewVoice() }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
