import Charts
import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No sets yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Finish a set and it shows up here.")
                    )
                } else {
                    List {
                        if store.records.count >= 2 {
                            Section("Progress") {
                                ProgressChart(records: store.records)
                            }
                        }
                        Section("Sets") {
                            ForEach(store.records) { record in
                                NavigationLink(value: record) {
                                    HistoryRow(record: record)
                                }
                            }
                            .onDelete { store.delete(at: $0) }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SetRecord.self) { record in
                HistoryDetailView(record: record)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Average set score over time, one line per exercise, with the A-grade
/// threshold marked. All data is local — Swift Charts, no dependencies.
private struct ProgressChart: View {
    let records: [SetRecord]

    /// Stored newest-first; charts want chronological order.
    private var chronological: [SetRecord] { records.reversed() }

    var body: some View {
        Chart {
            RuleMark(y: .value("Score", 90))
                .foregroundStyle(.green.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Grade A")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.8))
                }

            ForEach(chronological) { record in
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("Avg Score", record.averageScore)
                )
                .foregroundStyle(by: .value("Exercise", record.exercise))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Avg Score", record.averageScore)
                )
                .foregroundStyle(by: .value("Exercise", record.exercise))
            }
        }
        .chartYScale(domain: 0...100)
        .chartForegroundStyleScale([
            "Squat": Color.green,
            "Deadlift": Color.orange,
            "Bench": Color.blue,
        ])
        .frame(height: 220)
        .padding(.vertical, 8)
    }
}

private struct HistoryRow: View {
    let record: SetRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.grade)
                .font(.title2.weight(.black))
                .foregroundStyle(gradeColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.exercise)
                        .font(.headline)
                    if record.bestStreak >= 3 {
                        Text("🔥 \(record.bestStreak)")
                            .font(.caption.weight(.bold))
                    }
                }
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(record.reps.count) reps · avg \(record.averageScore)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var gradeColor: Color {
        switch record.grade {
        case "A": return .green
        case "B": return .mint
        case "F": return .red
        default: return .orange
        }
    }
}

private struct HistoryDetailView: View {
    let record: SetRecord

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.exercise)
                            .font(.headline)
                        Text(record.date.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(record.grade)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(record.averageScore >= 80 ? .green : .orange)
                }
                if record.bestStreak >= 3 {
                    Label("Best streak: \(record.bestStreak) clean in a row", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Reps") {
                ForEach(record.reps) { rep in
                    HStack {
                        Text("Rep \(rep.index)")
                            .font(.headline)
                        Spacer()
                        if rep.isClean {
                            Text("Clean")
                                .foregroundStyle(.green)
                        } else {
                            Text(rep.faults.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                        Text("\(rep.score)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .navigationTitle("\(record.exercise) Set")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
