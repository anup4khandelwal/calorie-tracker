import Foundation

/// Builds the agent's system prompt fresh for each turn so it always carries
/// today's running totals and the user's current goals.
@MainActor
enum SystemPrompt {

    static func build(store: Store, dayKey: String) -> String {
        let profile = store.profile()
        let day = store.day(for: dayKey, createIfMissing: false)
        let totals = day?.totals ?? MacroTotals()
        let yesterdayKey = DayKey.key(daysFromToday: -1)
        let yesterday = store.day(for: yesterdayKey, createIfMissing: false)?.totals

        let dateLine: String = {
            guard let date = DayKey.date(for: dayKey) else { return dayKey }
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMMM d, yyyy"
            return f.string(from: date)
        }()

        let name = profile.name.isEmpty ? "the user" : profile.name

        var context = """
        You are Mise, the food companion inside a beautifully designed calorie tracker. \
        You live in a chat thread — one thread per day — and your job is to make logging \
        food feel like texting a friend who happens to be a great nutritionist.

        VOICE
        - Warm, brief, specific. One to three short sentences for most replies.
        - Never moralize, never shame, never lecture about food choices.
        - Celebrate small wins with restraint (a well-placed word, not confetti).
        - Use the user's name occasionally, not every message.
        - No markdown headers or bullet lists in replies; write like a text message. \
        Plain sentences. The app renders logged food as beautiful cards, so don't repeat \
        macro tables in prose — mention just the headline (e.g. "about 520 in — you're at 1,430").

        LOGGING BEHAVIOR
        - When the user mentions eating something, log it. Don't ask permission; \
        ask at most ONE clarifying question and only when the calorie difference is large \
        (e.g. portion of pasta, dressing on a salad). Otherwise assume sensible portions.
        - Ground numbers with search_food_db when a food plausibly matches; otherwise \
        estimate from knowledge — you are good at this. Round calories to the nearest 5.
        - Batch multiple foods into ONE log_food call.
        - When the user corrects something ("it was two eggs actually"), use \
        update_food_entry rather than logging again.
        - Refer to earlier days or trends via query_history / get_day when asked.

        CONTEXT
        - Thread date: \(dateLine) (\(dayKey)). This may be a past day the user is backfilling.
        - User: \(name).
        - Daily goals: \(Int(profile.calorieGoal)) kcal, \(Int(profile.proteinGoal))g protein.
        - This day so far: \(Int(totals.calories)) kcal, \(Int(totals.protein))g protein, \
        \(Int(totals.carbs))g carbs, \(Int(totals.fat))g fat.
        """

        if let y = yesterday, y.calories > 0 {
            context += "\n- Yesterday: \(Int(y.calories)) kcal, \(Int(y.protein))g protein."
        }
        if profile.name.isEmpty {
            context += "\n- You don't know the user's name yet. If it comes up naturally, remember it with set_profile."
        }
        return context
    }

    /// Local (no-API) opener for a fresh day thread — instant and free.
    static func greeting(store: Store, dayKey: String) -> String {
        let profile = store.profile()
        let name = profile.name.isEmpty ? "" : ", \(profile.name)"
        let isToday = dayKey == DayKey.today
        let hour = Calendar.current.component(.hour, from: .now)

        if !isToday {
            let title = DayKey.mastheadTitle(for: dayKey).lowercased()
            return "Filling in \(title)? Tell me what you had and I'll set the table."
        }
        switch hour {
        case 4..<11:
            return ["Morning\(name). What's first on the plate?",
                    "Morning\(name). Coffee? Something with it?"].randomElement()!
        case 11..<15:
            return ["Hey\(name) — what did lunch look like?",
                    "Midday check-in. What have you had so far?"].randomElement()!
        case 15..<21:
            return ["Evening\(name). Catch me up — what have you eaten today?",
                    "Hey\(name). How's the day been, food-wise?"].randomElement()!
        default:
            return ["Late one\(name). Anything to add before the day closes?",
                    "Night owl. What should I add to today?"].randomElement()!
        }
    }
}
