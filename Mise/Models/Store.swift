import Foundation
import SwiftData

/// Thin convenience layer over the ModelContext for the operations the agent
/// tools and views share. All calls are MainActor — SwiftData context affinity.
@MainActor
struct Store {
    let context: ModelContext

    // MARK: Days

    func day(for key: String, createIfMissing: Bool = true) -> DayLog? {
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        guard createIfMissing else { return nil }
        let fresh = DayLog(dayKey: key)
        context.insert(fresh)
        return fresh
    }

    /// All days that have at least one entry, newest first (for the timeline).
    func daysWithEntries() -> [DayLog] {
        let descriptor = FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { !$0.entries.isEmpty }
    }

    /// Days in an inclusive key range (keys sort lexicographically = chronologically).
    func days(from startKey: String, to endKey: String) -> [DayLog] {
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { $0.dayKey >= startKey && $0.dayKey <= endKey },
            sortBy: [SortDescriptor(\.dayKey)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Entries

    func entry(id: UUID) -> FoodEntry? {
        var descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func entries(ids: [UUID]) -> [FoodEntry] {
        ids.compactMap { entry(id: $0) }
    }

    // MARK: Profile

    func profile() -> UserProfile {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let fresh = UserProfile()
        context.insert(fresh)
        return fresh
    }

    func save() {
        try? context.save()
    }
}
