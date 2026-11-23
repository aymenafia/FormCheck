import RevenueCat
import SwiftUI

/// Why the paywall is showing — drives the headline so it always speaks to
/// the moment the user is in.
enum PaywallContext: Identifiable, Equatable {
    case onboarding
    case afterFreeSet(grade: String, score: Int)
    case freeSetUsed
    case settings

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .afterFreeSet: return "afterFreeSet"
        case .freeSetUsed: return "freeSetUsed"
        case .settings: return "settings"
        }
    }
}

/// Soft, honest paywall (Guideline 3.1.2-safe): real trial terms read from
/// StoreKit, clear renewal price, a real reminder notification, and a close
/// button — users who aren't ready keep a free daily set instead of deleting.
struct PaywallView: View {
    @ObservedObject var store: EntitlementStore
    let context: PaywallContext
    let onClose: () -> Void

    @AppStorage("quiz.goal") private var goal = ""
    @State private var selectedID = EntitlementStore.yearlyID
    @State private var isPurchasing = false
    @State private var showClose = false
    @State private var appeared = false

    private var selected: Package? {
        store.packages.first { $0.storeProduct.productIdentifier == selectedID }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlowBackground(glowAt: UnitPoint(x: 0.5, y: 0.15), intensity: 0.32)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    plans
                    if let days = selected?.trialDays { timeline(days: days) }
                    benefits
                    Color.clear.frame(height: 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) { footer }

            if showClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .accessibilityLabel("Close")
                .padding(.leading, 16)
                .padding(.top, 6)
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadProducts()
            // The close button fades in after a beat — visible, never hidden.
            try? await Task.sleep(nanoseconds: context == .onboarding ? 2_500_000_000 : 800_000_000)
            withAnimation { showClose = true }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true } }
        .onChange(of: store.isSubscribed) { if store.isSubscribed { onClose() } }
        .alert("Something went wrong",
               isPresented: Binding(get: { store.lastError != nil },
                                    set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }

    // MARK: - Hero

    private var headline: (String, String) {
        switch context {
        case .onboarding:
            return ("Lift like someone's\nalways watching.", goalLine)
        case .afterFreeSet(let grade, let score):
            return ("That set: \(grade) · \(score)/100.\nNow make every set count.",
                    "Pro coaches every rep, every lift, every day — and shows you exactly what to fix.")
        case .freeSetUsed:
            return ("Today's free set is done.\nBones wants more.",
                    "Go Pro for unlimited sets on all 4 lifts. Or come back tomorrow for another free set.")
        case .settings:
            return ("Unlock FormCheck Pro", goalLine)
        }
    }

    private var goalLine: String {
        if goal.contains("stronger") { return "Clean reps move more weight. Bones checks depth, lean and tempo on every single one." }
        if goal.contains("muscle") { return "Full range, controlled tempo, every rep. That's where the growth is." }
        if goal.contains("injury") { return "Catch knee cave and forward lean the moment they happen — not months later." }
        return "Real-time form coaching on your phone. No coach, no guesswork."
    }

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Mascot(pose: heroPose, height: 170)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                if case .afterFreeSet(let grade, _) = context {
                    Text(grade)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.lime))
                        .shadow(color: .lime.opacity(0.6), radius: 14)
                        .offset(x: 30, y: 20)
                }
            }
            Text(headline.0)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(headline.1)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    private var heroPose: Mascot.Pose {
        switch context {
        case .afterFreeSet: return .win
        case .freeSetUsed: return .thumbs
        default: return .squat
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("figure.strengthtraining.traditional", "Unlimited sets", "Squat, deadlift, overhead press & lunge")
            benefit("waveform.path.ecg", "Live coaching on every rep", "Depth, lean, knee cave, bar path, tempo")
            benefit("film.stack", "Slow-mo skeleton replays", "See your worst rep. Share your best.")
            benefit("chart.line.uptrend.xyaxis", "Form score history", "Watch your grades climb week by week")
            benefit("lock.shield", "100% on-device", "Your video never leaves your phone")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func benefit(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.lime)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.lime.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(sub).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Trial timeline

    private func timeline(days: Int) -> some View {
        let remindDay = max(days - 2, 1)
        return VStack(alignment: .leading, spacing: 0) {
            Text("How your free trial works")
                .font(.headline).foregroundStyle(.white)
                .padding(.bottom, 14)
            row("lock.open.fill", "Today", "Unlock everything. Film your first Pro set.", active: true, line: true)
            row("bell.badge.fill", "Day \(remindDay)", "We send you a reminder notification.", active: true, line: true)
            row("crown.fill", "Day \(days)", "Trial ends. Cancel before then and pay nothing.", active: false, line: false)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ icon: String, _ title: String, _ sub: String, active: Bool, line: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(active ? Color.black : Color.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(active ? Color.lime : Color.white.opacity(0.12)))
                if line {
                    Rectangle()
                        .fill(LinearGradient(colors: [.lime, .lime.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(sub).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 5)
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if store.packages.isEmpty {
            if store.isLoadingProducts {
                ProgressView("Loading plans…").tint(.lime).padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    Text("Couldn't load plans. Check your connection.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    Button("Try Again") { Task { await store.loadProducts() } }
                        .buttonStyle(.bordered).tint(.lime)
                }
                .padding(.vertical, 20)
            }
        } else {
            VStack(spacing: 12) {
                if let yearly = store.annual { planCard(yearly, title: "Yearly", badge: savingsBadge) }
                if let weekly = store.weekly { planCard(weekly, title: "Weekly", badge: nil) }
            }
        }
    }

    private var savingsBadge: String {
        guard let y = store.annual?.storeProduct.price, let w = store.weekly?.storeProduct.price, w > 0 else { return "BEST VALUE" }
        let full = w * 52
        let pct = Int((NSDecimalNumber(decimal: (full - y) / full).doubleValue * 100).rounded())
        return pct > 0 ? "SAVE \(pct)%" : "BEST VALUE"
    }

    private func planCard(_ package: Package, title: String, badge: String?) -> some View {
        let id = package.storeProduct.productIdentifier
        let isSel = selectedID == id
        let product = package.storeProduct
        let detail: String = {
            if let days = package.trialDays {
                return "\(days) days free, then \(product.localizedPriceString)/\(package.periodWord)"
            }
            return "\(product.localizedPriceString) billed \(package.periodWord == "year" ? "yearly" : "weekly")"
        }()
        return Button {
            withAnimation(.snappy) { selectedID = id }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSel ? Color.lime : Color.white.opacity(0.3))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline).foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.lime, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    Text(detail).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(package.perWeekPrice ?? product.localizedPriceString)
                        .font(.headline.weight(.heavy)).foregroundStyle(.white)
                    Text("per week").font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .card(highlighted: isSel)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: buy) {
                ZStack {
                    if isPurchasing { ProgressView().tint(.black) } else { Text(ctaTitle) }
                }
            }
            .buttonStyle(LimeButtonStyle(enabled: selected != nil))
            .disabled(isPurchasing || selected == nil)

            Text(reassurance)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected?.trialDays != nil ? Color.lime : Color.white.opacity(0.6))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Button("Restore") { Task { await store.restorePurchases() } }
                Link("Terms", destination: URL(string: "https://formcheck.aymenafia.workers.dev/terms")!)
                Link("Privacy", destination: URL(string: "https://formcheck.aymenafia.workers.dev/privacy")!)
                if context != .settings {
                    Button("Not now", action: onClose)
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Color.ink.opacity(0), Color.ink, Color.ink], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var ctaTitle: String {
        if let d = selected?.trialDays { return "Start My \(d)-Day Free Trial" }
        return "Unlock FormCheck Pro"
    }

    private var reassurance: String {
        guard let p = selected else { return " " }
        if p.trialDays != nil {
            return "No payment now · Cancel anytime · Then \(p.storeProduct.localizedPriceString)/\(p.periodWord)"
        }
        return "\(p.storeProduct.localizedPriceString)/\(p.periodWord) · Auto-renews · Cancel anytime"
    }

    private func buy() {
        guard let p = selected else { return }
        isPurchasing = true
        Task {
            await store.purchase(p)
            isPurchasing = false
        }
    }
}
