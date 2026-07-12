import StoreKit
import SwiftUI

/// Hard paywall: yearly pre-selected, weekly carries the 3-day free trial.
struct PaywallView: View {
    @ObservedObject var store: EntitlementStore
    @State private var selectedID = EntitlementStore.yearlyID
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 20) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    benefits
                    planCards
                }
                .padding(.top, 24)
            }
            footer
        }
        .padding(.horizontal, 24)
        .alert("Something went wrong",
               isPresented: Binding(
                   get: { store.lastError != nil },
                   set: { if !$0 { store.lastError = nil } }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Unlock your AI squat coach")
                .font(.title.weight(.black))
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("waveform.path.ecg", "Live form scoring on every rep")
            benefit("speaker.wave.2.fill", "Voice callouts — depth, lean, tempo")
            benefit("film.fill", "Slow-mo skeleton replays to share")
            benefit("lock.shield.fill", "100% on-device. Video never leaves your phone")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 26)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                ProgressView("Loading plans…")
                    .padding(.vertical, 24)
            } else {
                if let yearly = store.yearly {
                    planCard(
                        id: yearly.id,
                        title: "Yearly",
                        price: "\(yearly.displayPrice) / year",
                        detail: "That's under $0.80 a week",
                        badge: "BEST VALUE · SAVE 89%"
                    )
                }
                if let weekly = store.weekly {
                    planCard(
                        id: weekly.id,
                        title: "Weekly",
                        price: "\(weekly.displayPrice) / week",
                        detail: "3-day free trial, cancel anytime",
                        badge: nil
                    )
                }
            }
        }
    }

    private func planCard(id: String, title: String, price: String, detail: String, badge: String?) -> some View {
        let isSelected = selectedID == id
        return Button {
            selectedID = id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.black)
                }
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(price)
                        .font(.headline)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                purchaseSelected()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text(selectedID == EntitlementStore.weeklyID ? "Start My Free Trial" : "Continue")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isPurchasing || store.products.isEmpty)

            // Guideline 3.1.2: auto-renew disclosure at the point of purchase.
            Text("Subscriptions renew automatically until cancelled. Cancel anytime in Settings → Apple Account → Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task { await store.restorePurchases() }
                }
                Link("Terms", destination: URL(string: "https://github.com/aymenafia/FormCheck/blob/main/TERMS.md")!)
                Link("Privacy", destination: URL(string: "https://github.com/aymenafia/FormCheck/blob/main/PRIVACY.md")!)
                #if DEBUG
                Button("Skip (dev)") {
                    UserDefaults.standard.set(true, forKey: "debug.bypassPaywall")
                }
                #endif
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func purchaseSelected() {
        guard let product = store.products.first(where: { $0.id == selectedID }) else { return }
        isPurchasing = true
        Task {
            await store.purchase(product)
            isPurchasing = false
        }
    }
}

#Preview {
    PaywallView(store: EntitlementStore())
        .preferredColorScheme(.dark)
}
