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
    @EnvironmentObject private var store: EntitlementStore

    var isPro = false
    var onUpgrade: () -> Void = {}

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isPro {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FormCheck Pro is active").font(.headline)
                                if let end = store.trialEndDate {
                                    Text("Free trial until \(end.formatted(date: .abbreviated, time: .omitted)). We'll remind you 2 days before.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "crown.fill").foregroundStyle(Color.lime)
                        }
                    } else {
                        Button(action: onUpgrade) {
                            Label("Try FormCheck Pro free", systemImage: "crown.fill")
                                .font(.headline)
                                .foregroundStyle(Color.lime)
                        }
                    }
                    Button("Restore Purchases") { Task { await store.restorePurchases() } }
                    Button("Redeem Offer Code") { store.presentCodeRedemption() }
                } header: {
                    Text("Membership")
                }

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

                Section("Support") {
                    Link("Help & FAQ",
                         destination: URL(string: "https://formcheck.aymenafia.workers.dev/support")!)
                    Link("Report a Problem",
                         destination: URL(string: "mailto:afia.med.aymen@gmail.com?subject=FormCheck%20Bug%20Report")!)
                    Link("Email Support",
                         destination: URL(string: "mailto:afia.med.aymen@gmail.com?subject=FormCheck%20Support")!)
                }

                Section {
                    Link("Manage Subscription",
                         destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Link("Privacy Policy",
                         destination: URL(string: "https://formcheck.aymenafia.workers.dev/privacy")!)
                    Link("Terms of Use",
                         destination: URL(string: "https://formcheck.aymenafia.workers.dev/terms")!)
                }

                Section {
                } footer: {
                    Text("FormCheck \(appVersion) · All processing happens on-device. Your video never leaves your phone.")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .alert("Purchases",
                   isPresented: Binding(get: { store.lastError != nil },
                                        set: { if !$0 { store.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.lastError ?? "")
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
