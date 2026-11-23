import Charts
import SwiftUI

struct HistoryView: View {
    var isPro = true
    var onUpgrade: () -> Void = {}

    @ObservedObject private var store = HistoryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var filter = "All"

    private var lifts: [String] { ["All"] + Exercise.available.map(\.rawValue).filter { l in store.records.contains { $0.exercise == l } } }
    private var filtered: [SetRecord] { filter == "All" ? store.records : store.records.filter { $0.exercise == filter } }

    var body: some View {
        NavigationStack {
            ZStack {
                GlowBackground(glowAt: .top, intensity: 0.18)
                if store.records.isEmpty {
                    VStack(spacing: 14) {
                        Mascot(pose: .wave, height: 180)
                        Text("No sets yet").font(.title2.weight(.heavy))
                        Text("Finish a set and Bones logs it here — grades, reps, and your progress over time.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List {
                        if lifts.count > 2 {
                            Picker("Lift", selection: $filter) {
                                ForEach(lifts, id: \.self) { Text($0 == "Overhead Press" ? "Press" : $0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                        Section {
                            insights
                        }
                        .listRowBackground(Color.card)
                        if filtered.count >= 2 {
                            Section("Form score trend") {
                                ZStack {
                                    ProgressChart(records: filtered)
                                        .blur(radius: isPro ? 0 : 7)
                                    if !isPro { proLock }
                                }
                            }
                            .listRowBackground(Color.card)
                        }
                        Section("Sets") {
                            ForEach(filtered) { record in
                                NavigationLink(value: record) { HistoryRow(record: record) }
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { filtered[$0].id }
                                store.delete(at: IndexSet(store.records.indices.filter { ids.contains(store.records[$0].id) }))
                            }
                        }
                        .listRowBackground(Color.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SetRecord.self) { HistoryDetailView(record: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Insights

    private var insights: some View {
        let recs = filtered
        let avg = recs.isEmpty ? 0 : recs.map(\.averageScore).reduce(0, +) / recs.count
        let reps = recs.reduce(0) { $0 + $1.reps.count }
        let faults = recs.flatMap { $0.reps.flatMap(\.faults) }
        let common = Dictionary(grouping: faults, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        let delta = trendDelta(recs)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                insight("\(recs.count)", "sets")
                insight("\(reps)", "reps")
                insight("\(avg)", "avg score")
                insight(delta.map { ($0 >= 0 ? "+" : "") + "\($0)" } ?? "–", "vs. first sets")
            }
            if let common {
                Label {
                    Text("Your most common fault: **\(common)**")
                } icon: {
                    Image(systemName: "scope").foregroundStyle(.orange)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 6)
    }

    /// Average of the latest 3 sets minus the average of the first 3.
    private func trendDelta(_ recs: [SetRecord]) -> Int? {
        guard recs.count >= 4 else { return nil }
        let newest = recs.prefix(3).map(\.averageScore), oldest = recs.suffix(3).map(\.averageScore)
        return newest.reduce(0, +) / newest.count - oldest.reduce(0, +) / oldest.count
    }

    private func insight(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.lime)
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var proLock: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.title2).foregroundStyle(Color.lime)
            Text("See your form score climb").font(.headline)
            Button {
                dismiss()
                onUpgrade()
            } label: {
                Text("Unlock with Pro").padding(.horizontal, 8)
            }
            .buttonStyle(LimeButtonStyle())
            .frame(width: 210)
        }
    }
}

/// Average set score over time, one line per exercise, with the A-grade
/// threshold marked. All data is local — Swift Charts, no dependencies.
private struct ProgressChart: View {
    let records: [SetRecord]

    private var chronological: [SetRecord] { records.reversed() }

    var body: some View {
        Chart {
            RuleMark(y: .value("Score", 90))
                .foregroundStyle(Color.lime.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Grade A").font(.caption2).foregroundStyle(Color.lime.opacity(0.8))
                }
            ForEach(chronological) { record in
                LineMark(x: .value("Date", record.date), y: .value("Avg Score", record.averageScore))
                    .foregroundStyle(by: .value("Exercise", record.exercise))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", record.date), y: .value("Avg Score", record.averageScore))
                    .foregroundStyle(by: .value("Exercise", record.exercise))
            }
        }
        .chartYScale(domain: 0...100)
        .chartForegroundStyleScale(domain: Self.domain, range: Self.colors)
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    // Every lift a record can hold must be in the domain, or its line drops out.
    static let domain = Exercise.allCases.map(\.rawValue)
    static let colors: [Color] = Exercise.allCases.map {
        switch $0 {
        case .squat: return .lime
        case .deadlift: return .orange
        case .overheadPress: return .cyan
        case .lunge: return .pink
        case .bench: return .blue
        case .freestyle: return .purple
        }
    }
}

private struct HistoryRow: View {
    let record: SetRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.grade)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(gradeColor(record.grade))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.exercise).font(.headline)
                    if record.bestStreak >= 3 {
                        Text("🔥 \(record.bestStreak)").font(.caption.weight(.bold))
                    }
                }
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(record.reps.count) reps · \(record.averageScore)")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

func gradeColor(_ grade: String) -> Color {
    switch grade {
    case "A", "B": return .lime
    case "C": return .yellow
    case "F": return .red
    default: return .orange
    }
}

private struct HistoryDetailView: View {
    let record: SetRecord

    private var topFault: FormFault? {
        let names = record.reps.flatMap(\.faults)
        let top = Dictionary(grouping: names, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        return top.flatMap(FormFault.init(rawValue:))
    }

    var body: some View {
        ZStack {
            GlowBackground(glowAt: .top, intensity: 0.18)
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.exercise).font(.title3.weight(.heavy))
                            Text(record.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline).foregroundStyle(.secondary)
                            if record.bestStreak >= 3 {
                                Label("\(record.bestStreak) clean in a row", systemImage: "flame.fill")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(record.grade)
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .foregroundStyle(gradeColor(record.grade))
                            Text("\(record.averageScore)/100").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .card()

                    if let topFault { DrillCard(fault: topFault) }

                    VStack(spacing: 10) {
                        ForEach(record.reps) { rep in
                            HStack {
                                Text("\(rep.score)")
                                    .font(.system(.headline, design: .rounded).weight(.black).monospacedDigit())
                                    .foregroundStyle(rep.isClean ? Color.black : Color.white)
                                    .frame(width: 44, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(rep.isClean ? Color.lime : Color.orange.opacity(0.35)))
                                Text("Rep \(rep.index)").font(.subheadline.weight(.bold))
                                Spacer()
                                Text(rep.isClean ? "Clean" : rep.faults.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(rep.isClean ? Color.lime : Color.orange)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding(16)
                    .card()
                }
                .padding(20)
            }
        }
        .navigationTitle("\(record.exercise) Set")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView().preferredColorScheme(.dark)
}
