import Foundation

/// A tool_use block captured from the stream, input JSON fully accumulated.
struct ToolCall {
    let id: String
    let name: String
    let inputJSON: String
}

/// What a tool execution produced: the JSON to send back, plus side effects
/// the UI cares about (entries created this turn get imagery + cards).
struct ToolOutcome {
    let resultJSON: String
    let isError: Bool
    var createdEntryIDs: [UUID] = []
}

/// Executes the agent's tools against SwiftData. Everything runs on the main
/// actor because SwiftData contexts are actor-bound.
@MainActor
struct AgentToolbox {
    let store: Store
    let dayKey: String

    // MARK: Schemas (wire format)

    static let schemas: [[String: Any]] = [
        [
            "name": "search_food_db",
            "description": "Search the built-in nutrition database for a food. Returns per-100g macros plus a typical serving. Use this to ground calorie numbers before logging; if nothing matches, estimate from your own knowledge and note it.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Food name, e.g. 'grilled chicken'"],
                ],
                "required": ["query"],
            ],
        ],
        [
            "name": "log_food",
            "description": "Log one or more foods to the user's day. Compute calories and macros for the actual portion (use search_food_db to ground when possible). Returns created entry ids and the day's updated totals.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "items": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string", "description": "Short display name, e.g. 'Avocado toast'"],
                                "emoji": ["type": "string", "description": "Single emoji for the food"],
                                "meal": ["type": "string", "enum": ["breakfast", "lunch", "dinner", "snack"]],
                                "grams": ["type": "number", "description": "Estimated portion weight in grams"],
                                "serving_description": ["type": "string", "description": "Human portion, e.g. '2 slices'"],
                                "calories": ["type": "number"],
                                "protein": ["type": "number", "description": "grams"],
                                "carbs": ["type": "number", "description": "grams"],
                                "fat": ["type": "number", "description": "grams"],
                            ],
                            "required": ["name", "emoji", "meal", "grams", "serving_description", "calories", "protein", "carbs", "fat"],
                        ],
                    ],
                ],
                "required": ["items"],
            ],
        ],
        [
            "name": "update_food_entry",
            "description": "Update fields of an existing entry by id (from log_food or get_day). Only include fields that change.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "name": ["type": "string"],
                    "emoji": ["type": "string"],
                    "meal": ["type": "string", "enum": ["breakfast", "lunch", "dinner", "snack"]],
                    "grams": ["type": "number"],
                    "serving_description": ["type": "string"],
                    "calories": ["type": "number"],
                    "protein": ["type": "number"],
                    "carbs": ["type": "number"],
                    "fat": ["type": "number"],
                ],
                "required": ["id"],
            ],
        ],
        [
            "name": "delete_food_entry",
            "description": "Remove an entry from the log by id.",
            "input_schema": [
                "type": "object",
                "properties": ["id": ["type": "string"]],
                "required": ["id"],
            ],
        ],
        [
            "name": "get_day",
            "description": "Get the full food log and totals for a date (defaults to the current thread's day).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "date": ["type": "string", "description": "yyyy-MM-dd; omit for this thread's day"],
                ],
            ],
        ],
        [
            "name": "query_history",
            "description": "Daily calorie/macro totals for the last N days, plus averages and the logging streak. Use for questions like 'how am I doing this week?'",
            "input_schema": [
                "type": "object",
                "properties": [
                    "days_back": ["type": "integer", "description": "How many days including today (default 7, max 60)"],
                ],
            ],
        ],
        [
            "name": "set_profile",
            "description": "Update the user's profile: preferred name and daily calorie/protein goals.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string"],
                    "calorie_goal": ["type": "number"],
                    "protein_goal": ["type": "number"],
                ],
            ],
        ],
    ]

    // MARK: Execution

    func execute(_ call: ToolCall) -> ToolOutcome {
        let input: [String: Any]
        if let data = call.inputJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            input = parsed
        } else if call.inputJSON.trimmingCharacters(in: .whitespaces).isEmpty {
            input = [:]
        } else {
            return ToolOutcome(resultJSON: #"{"error":"could not parse tool input"}"#, isError: true)
        }

        switch call.name {
        case "search_food_db": return searchFoodDB(input)
        case "log_food": return logFood(input)
        case "update_food_entry": return updateEntry(input)
        case "delete_food_entry": return deleteEntry(input)
        case "get_day": return getDay(input)
        case "query_history": return queryHistory(input)
        case "set_profile": return setProfile(input)
        default:
            return ToolOutcome(resultJSON: #"{"error":"unknown tool"}"#, isError: true)
        }
    }

    // MARK: Individual tools

    private func searchFoodDB(_ input: [String: Any]) -> ToolOutcome {
        let query = input["query"] as? String ?? ""
        let hits = NutritionDB.shared.search(query)
        let rows = hits.map { f -> [String: Any] in
            [
                "name": f.name,
                "per_100g": ["calories": f.kcal, "protein": f.p, "carbs": f.c, "fat": f.f],
                "typical_serving": ["grams": f.servingG, "description": f.serving],
                "emoji": f.emoji,
            ]
        }
        return json(["matches": rows, "note": rows.isEmpty ? "no match — estimate from your own knowledge" : "grounded"])
    }

    private func logFood(_ input: [String: Any]) -> ToolOutcome {
        guard let day = store.day(for: dayKey) else {
            return ToolOutcome(resultJSON: #"{"error":"day unavailable"}"#, isError: true)
        }
        guard let items = input["items"] as? [[String: Any]], !items.isEmpty else {
            return ToolOutcome(resultJSON: #"{"error":"items array required"}"#, isError: true)
        }

        var created: [[String: Any]] = []
        var ids: [UUID] = []
        for item in items {
            let entry = FoodEntry(
                name: item["name"] as? String ?? "Food",
                emoji: item["emoji"] as? String ?? "🍽️",
                meal: MealSlot(rawValue: item["meal"] as? String ?? "") ?? inferMealSlot(),
                grams: number(item["grams"]) ?? 100,
                servingDescription: item["serving_description"] as? String ?? "1 serving",
                calories: number(item["calories"]) ?? 0,
                protein: number(item["protein"]) ?? 0,
                carbs: number(item["carbs"]) ?? 0,
                fat: number(item["fat"]) ?? 0
            )
            entry.day = day
            store.context.insert(entry)
            ids.append(entry.id)
            created.append(["id": entry.id.uuidString, "name": entry.name, "calories": entry.calories])
        }
        store.save()

        let totals = day.totals
        var outcome = json([
            "logged": created,
            "day_totals": totalsDict(totals),
        ])
        outcome.createdEntryIDs = ids
        return outcome
    }

    private func updateEntry(_ input: [String: Any]) -> ToolOutcome {
        guard let idString = input["id"] as? String, let id = UUID(uuidString: idString),
              let entry = store.entry(id: id) else {
            return ToolOutcome(resultJSON: #"{"error":"entry not found"}"#, isError: true)
        }
        if let v = input["name"] as? String { entry.name = v }
        if let v = input["emoji"] as? String { entry.emoji = v }
        if let v = input["meal"] as? String, let slot = MealSlot(rawValue: v) { entry.meal = slot }
        if let v = number(input["grams"]) { entry.grams = v }
        if let v = input["serving_description"] as? String { entry.servingDescription = v }
        if let v = number(input["calories"]) { entry.calories = v }
        if let v = number(input["protein"]) { entry.protein = v }
        if let v = number(input["carbs"]) { entry.carbs = v }
        if let v = number(input["fat"]) { entry.fat = v }
        // Name changed → regenerate imagery next time it's requested.
        if input["name"] != nil { entry.imageFile = nil }
        store.save()
        let totals = entry.day?.totals ?? MacroTotals()
        return json(["updated": entry.id.uuidString, "day_totals": totalsDict(totals)])
    }

    private func deleteEntry(_ input: [String: Any]) -> ToolOutcome {
        guard let idString = input["id"] as? String, let id = UUID(uuidString: idString),
              let entry = store.entry(id: id) else {
            return ToolOutcome(resultJSON: #"{"error":"entry not found"}"#, isError: true)
        }
        let day = entry.day
        let name = entry.name
        store.context.delete(entry)
        store.save()
        return json(["deleted": name, "day_totals": totalsDict(day?.totals ?? MacroTotals())])
    }

    private func getDay(_ input: [String: Any]) -> ToolOutcome {
        let key = (input["date"] as? String) ?? dayKey
        guard let day = store.day(for: key, createIfMissing: false) else {
            return json(["date": key, "entries": [], "note": "nothing logged"])
        }
        let entries = day.sortedEntries.map { e -> [String: Any] in
            [
                "id": e.id.uuidString,
                "name": e.name,
                "meal": e.meal.rawValue,
                "serving": e.servingDescription,
                "grams": e.grams,
                "calories": e.calories,
                "protein": e.protein,
                "carbs": e.carbs,
                "fat": e.fat,
            ]
        }
        return json(["date": key, "entries": entries, "totals": totalsDict(day.totals)])
    }

    private func queryHistory(_ input: [String: Any]) -> ToolOutcome {
        let daysBack = min(max((input["days_back"] as? Int) ?? 7, 1), 60)
        let startKey = DayKey.key(daysFromToday: -(daysBack - 1))
        let days = store.days(from: startKey, to: DayKey.today)

        var rows: [[String: Any]] = []
        var sum = MacroTotals()
        var loggedDays = 0
        for day in days where !day.entries.isEmpty {
            let t = day.totals
            rows.append(["date": day.dayKey, "calories": t.calories.rounded(), "protein": t.protein.rounded(), "entries": day.entries.count])
            sum.calories += t.calories; sum.protein += t.protein; sum.carbs += t.carbs; sum.fat += t.fat
            loggedDays += 1
        }
        // Streak: consecutive logged days ending today or yesterday.
        var streak = 0
        var cursor = 0
        while cursor < 60 {
            let key = DayKey.key(daysFromToday: -cursor)
            let logged = store.day(for: key, createIfMissing: false).map { !$0.entries.isEmpty } ?? false
            if logged { streak += 1 } else if cursor > 0 { break }
            cursor += 1
        }
        let divisor = Double(max(loggedDays, 1))
        var average = MacroTotals()
        average.calories = sum.calories / divisor
        average.protein = sum.protein / divisor
        average.carbs = sum.carbs / divisor
        average.fat = sum.fat / divisor
        let avg: [String: Any] = loggedDays > 0 ? totalsDict(average) : [:]
        return json(["days": rows, "logged_day_count": loggedDays, "daily_average": avg, "current_streak_days": streak])
    }

    private func setProfile(_ input: [String: Any]) -> ToolOutcome {
        let profile = store.profile()
        if let v = input["name"] as? String { profile.name = v }
        if let v = number(input["calorie_goal"]) { profile.calorieGoal = v }
        if let v = number(input["protein_goal"]) { profile.proteinGoal = v }
        store.save()
        return json(["profile": ["name": profile.name, "calorie_goal": profile.calorieGoal, "protein_goal": profile.proteinGoal]])
    }

    // MARK: Helpers

    private func inferMealSlot() -> MealSlot {
        switch Calendar.current.component(.hour, from: .now) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }

    private func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: d
        case let i as Int: Double(i)
        case let n as NSNumber: n.doubleValue
        default: nil
        }
    }

    private func totalsDict(_ t: MacroTotals) -> [String: Any] {
        ["calories": t.calories.rounded(), "protein": t.protein.rounded(), "carbs": t.carbs.rounded(), "fat": t.fat.rounded()]
    }

    private func json(_ object: [String: Any]) -> ToolOutcome {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return ToolOutcome(resultJSON: #"{"error":"serialization failed"}"#, isError: true)
        }
        return ToolOutcome(resultJSON: string, isError: false)
    }
}
