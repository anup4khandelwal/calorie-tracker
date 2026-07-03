import Foundation

/// One row of the bundled food database. Macro values are per 100 g;
/// `servingG` + `serving` describe the typical portion.
struct FoodFact: Codable, Identifiable, Sendable {
    let name: String
    let aliases: [String]
    let kcal: Double
    let p: Double
    let c: Double
    let f: Double
    let servingG: Double
    let serving: String
    let emoji: String
    let cat: String

    var id: String { name }

    func scaled(grams: Double) -> (kcal: Double, p: Double, c: Double, f: Double) {
        let k = grams / 100.0
        return (kcal * k, p * k, c * k, f * k)
    }
}

/// Bundled seed database with a tiny fuzzy search. This grounds the agent's
/// numbers; anything not found here the model estimates itself (and says so).
struct NutritionDB: Sendable {
    let foods: [FoodFact]

    static let shared: NutritionDB = {
        guard
            let url = Bundle.main.url(forResource: "Foods", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let foods = try? JSONDecoder().decode([FoodFact].self, from: data)
        else {
            assertionFailure("Foods.json missing from bundle")
            return NutritionDB(foods: [])
        }
        return NutritionDB(foods: foods)
    }()

    /// Token-prefix fuzzy match over names + aliases, best first.
    func search(_ query: String, limit: Int = 6) -> [FoodFact] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        let scored: [(FoodFact, Double)] = foods.compactMap { food in
            var candidates = [food.name]
            candidates.append(contentsOf: food.aliases)
            let best = candidates.map { score(queryTokens, against: tokenize($0)) }.max() ?? 0
            return best > 0 ? (food, best) : nil
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }

    /// Fraction of query tokens that prefix-match a candidate token,
    /// weighted toward full-token matches.
    private func score(_ query: [String], against candidate: [String]) -> Double {
        guard !candidate.isEmpty else { return 0 }
        var total = 0.0
        for q in query {
            var best = 0.0
            for c in candidate {
                if c == q { best = max(best, 1.0) }
                else if c.hasPrefix(q) || q.hasPrefix(c) { best = max(best, 0.6) }
            }
            total += best
        }
        return total / Double(query.count)
    }
}
