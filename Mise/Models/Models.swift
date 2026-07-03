import Foundation
import SwiftData

// MARK: - Day

/// One day = one conversation thread + its food log.
/// `dayKey` is "yyyy-MM-dd" in the user's calendar — string keys keep
/// predicates trivial and immune to timezone drift.
@Model
final class DayLog {
    @Attribute(.unique) var dayKey: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.day)
    var messages: [ChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.day)
    var entries: [FoodEntry] = []

    init(dayKey: String) {
        self.dayKey = dayKey
        self.createdAt = .now
    }

    var sortedMessages: [ChatMessage] { messages.sorted { $0.createdAt < $1.createdAt } }
    var sortedEntries: [FoodEntry] { entries.sorted { $0.createdAt < $1.createdAt } }

    var totals: MacroTotals {
        entries.reduce(into: MacroTotals()) { $0.add($1) }
    }
}

struct MacroTotals {
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
    mutating func add(_ e: FoodEntry) {
        calories += e.calories; protein += e.protein; carbs += e.carbs; fat += e.fat
    }
}

// MARK: - Food entry

enum MealSlot: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack

    var label: String { rawValue.capitalized }
    var order: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }
}

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var mealRaw: String
    var grams: Double
    var servingDescription: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var createdAt: Date
    /// Filename of the generated studio image inside the image cache directory.
    var imageFile: String?
    var day: DayLog?

    init(
        name: String, emoji: String, meal: MealSlot, grams: Double,
        servingDescription: String, calories: Double, protein: Double,
        carbs: Double, fat: Double
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.mealRaw = meal.rawValue
        self.grams = grams
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.createdAt = .now
    }

    var meal: MealSlot {
        get { MealSlot(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }
}

// MARK: - Chat message

enum ChatRole: String, Codable {
    case user, agent
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    /// FoodEntry ids embedded in this message (rendered as cards inline).
    var entryIDs: [UUID]
    var day: DayLog?

    init(role: ChatRole, text: String, entryIDs: [UUID] = []) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = .now
        self.entryIDs = entryIDs
    }

    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .agent }
}

// MARK: - Profile

@Model
final class UserProfile {
    var name: String
    var calorieGoal: Double
    var proteinGoal: Double
    var onboarded: Bool

    init(name: String = "", calorieGoal: Double = 2200, proteinGoal: Double = 120, onboarded: Bool = false) {
        self.name = name
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.onboarded = onboarded
    }
}

// MARK: - Day keys

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { formatter.string(from: date) }
    static func date(for key: String) -> Date? { formatter.date(from: key) }

    static var today: String { key(for: .now) }

    static func key(daysFromToday offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return key(for: d)
    }

    /// "Thursday, July 3" style masthead title.
    static func mastheadTitle(for key: String) -> String {
        guard let date = date(for: key) else { return key }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    /// Short label for timeline sections, "Thu · Jul 3".
    static func shortTitle(for key: String) -> String {
        guard let date = date(for: key) else { return key }
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: date)
    }
}
