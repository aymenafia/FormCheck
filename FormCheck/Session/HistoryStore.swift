import Combine
import Foundation

struct RepRecord: Codable, Hashable, Identifiable {
    let index: Int
    let score: Int
    let faults: [String]

    var id: Int { index }
    var isClean: Bool { faults.isEmpty }
}

struct SetRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let exercise: String
    let viewMode: String
    let grade: String
    let averageScore: Int
    let bestStreak: Int
    let reps: [RepRecord]
}

extension SetRecord {
    init(summary: SetSummary, exercise: Exercise, viewMode: ViewMode) {
        var run = 0
        var best = 0
        let reps = summary.reps.map { score in
            run = score.faults.isEmpty ? run + 1 : 0
            best = max(best, run)
            return RepRecord(index: score.repIndex,
                             score: score.score,
                             faults: score.faults.map(\.rawValue))
        }
        self.init(id: UUID(),
                  date: Date(),
                  exercise: exercise.rawValue,
                  viewMode: viewMode.rawValue,
                  grade: summary.grade,
                  averageScore: summary.averageScore,
                  bestStreak: best,
                  reps: reps)
    }
}

/// Set history as a JSON file in Documents — stats only (a few KB per set),
/// no video. Newest first. All mutations happen on the main thread; disk
/// writes go to a background queue.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var records: [SetRecord] = []

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("formcheck-history.json")

    init() {
        load()
    }

    func add(_ record: SetRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SetRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        let snapshot = records
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
