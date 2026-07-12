import StoreKit
import SwiftUI

/// Conversion-optimized hard paywall. Ethical psychology only — no fake
/// urgency or hidden terms (both violate 3.1.2 and burn trust):
///  • Trial timeline (Today → reminder → billed) to remove payment anxiety
///  • Trial as the default path, with a benefit-led CTA
///  • Per-week anchoring so the annual plan reads as the obvious value
struct PaywallView: View {
    @ObservedObject var store: EntitlementStore
    @State private var selectedID = EntitlementStore.yearlyID
    @State private var isPurchasing = false

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    benefits
                    if let days = trialDays(selectedProduct) {
                        trialTimeline(days: days)
                    }
                    planCards
                }
                .padding(.top, 20)
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Fix your form.\nLift with confidence.")
                .font(.title.weight(.black))
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("waveform.path.ecg", "Live form scoring on every rep")
            benefit("speaker.wave.2.fill", "A coach that calls out mistakes as you lift")
            benefit("film.fill", "Slow-mo replays worth sharing")
            benefit("lock.shield.fill", "100% on-device — your video never leaves your phone")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 26)
            Text(text)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Trial timeline (the conversion driver)

    private func trialTimeline(days: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How your \(days)-day free trial works")
                .font(.headline)
                .padding(.bottom, 14)

            timelineRow(icon: "lock.open.fill", color: .green,
                        title: "Today",
                        subtitle: "Full access unlocks. Scan your first set in seconds.",
                        showLine: true)
            timelineRow(icon: "bell.fill", color: .green,
                        title: "Day \(max(days - 1, 1))",
                        subtitle: "We'll remind you before your trial ends.",
                        showLine: true)
            timelineRow(icon: "star.fill", color: .secondary,
                        title: "Day \(days)",
                        subtitle: "Your plan begins — cancel anytime before then and pay nothing.",
                        showLine: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func timelineRow(icon: String, color: Color, title: String,
                             subtitle: String, showLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color == .secondary ? Color.secondary : .black)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(color == .secondary ? Color.white.opacity(0.15) : Color.green))
                if showLine {
                    Rectangle()
                        .fill(Color.green.opacity(0.4))
                        .frame(width: 3, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    private var planCards: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                if store.isLoadingProducts {
                    ProgressView("Loading plans…")
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        Text("Couldn't load subscription plans.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Try Again") { Task { await store.loadProducts() } }
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 20)
                }
            } else {
                if let yearly = store.yearly {
                    planCard(product: yearly, title: "Yearly",
                             price: "\(yearly.displayPrice) / year",
                             detail: yearlyDetail(for: yearly),
                             badge: savingsBadge(yearly: yearly, weekly: store.weekly))
                }
                if let weekly = store.weekly {
                    planCard(product: weekly, title: "Weekly",
                             price: "\(weekly.displayPrice) / week",
                             detail: trialDays(weekly).map { "\($0)-day free trial, then billed weekly" } ?? "Billed weekly",
                             badge: nil)
                }
            }
        }
    }

    private func yearlyDetail(for yearly: Product) -> String {
        let perWeek = yearly.price / 52
        let base = "Just \(perWeek.formatted(yearly.priceFormatStyle)) a week"
        if let days = trialDays(yearly) { return "\(days)-day free trial · \(base)" }
        return base
    }

    private func savingsBadge(yearly: Product, weekly: Product?) -> String {
        guard let weekly else { return "BEST VALUE" }
        let fullYearAtWeekly = weekly.price * 52
        guard fullYearAtWeekly > 0 else { return "BEST VALUE" }
        let fraction = (fullYearAtWeekly - yearly.price) / fullYearAtWeekly
        let percent = Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded())
        guard percent > 0 else { return "BEST VALUE" }
        return "BEST VALUE · SAVE \(percent)%"
    }

    private func planCard(product: Product, title: String, price: String,
                          detail: String, badge: String?) -> some View {
        let isSelected = selectedID == product.id
        return Button {
            selectedID = product.id
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
                    Text(title).font(.headline)
                    Spacer()
                    Text(price).font(.headline)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.green.opacity(0.15) : Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer / CTA

    private var footer: some View {
        VStack(spacing: 8) {
            Button(action: purchaseSelected) {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text(ctaTitle).font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isPurchasing || store.products.isEmpty)

            // Reassurance directly under the button — the anxiety killer.
            if trialDays(selectedProduct) != nil {
                Label("No charge today · Cancel anytime", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }

            Text("Auto-renews until cancelled in Settings → Apple Account → Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Restore") { Task { await store.restorePurchases() } }
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

    private var ctaTitle: String {
        if let days = trialDays(selectedProduct) {
            return "Start My \(days)-Day Free Trial"
        }
        return "Continue"
    }

    // MARK: - Trial detection (drives all trial messaging honestly)

    /// Number of free-trial days on a product, or nil if it has no free trial.
    /// Reads the real StoreKit intro offer, so messaging can never claim a
    /// trial the product doesn't actually have.
    private func trialDays(_ product: Product?) -> Int? {
        guard let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        switch p.unit {
        case .day: return p.value
        case .week: return p.value * 7
        case .month: return p.value * 30
        case .year: return p.value * 365
        @unknown default: return p.value
        }
    }

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
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
