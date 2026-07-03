import SwiftUI
import CryptoKit
import Observation

/// Generates and caches the studio food photography.
///
/// Every food image in Mise comes from one locked "shoot": same plate, same
/// light, same background — so the timeline reads like a single magazine
/// spread no matter when a dish was logged. Images are keyed by normalized
/// food name, so "banana" today reuses the banana from last week.
@MainActor
@Observable
final class FoodImageEngine {

    /// Loaded images keyed by cache filename.
    private(set) var images: [String: UIImage] = [:]
    /// Entry ids currently waiting on generation (drives shimmer placeholders).
    private(set) var generating: Set<UUID> = []

    private var inFlightKeys: Set<String> = []
    private let store: Store

    private static let models = ["gemini-3.1-flash-image", "gemini-2.5-flash-image"]

    init(store: Store) {
        self.store = store
    }

    // MARK: Public

    /// Ensure `entry` has an image: load from disk if cached, otherwise
    /// generate. Safe to call repeatedly from view onAppear.
    func ensure(_ entry: FoodEntry) {
        let key = Self.cacheKey(for: entry.name)

        if images[key] != nil {
            if entry.imageFile != key { entry.imageFile = key; store.save() }
            return
        }
        if let fromDisk = loadFromDisk(key) {
            images[key] = fromDisk
            if entry.imageFile != key { entry.imageFile = key; store.save() }
            return
        }
        guard KeyVault.hasGeminiKey, !inFlightKeys.contains(key) else { return }

        inFlightKeys.insert(key)
        generating.insert(entry.id)
        let entryID = entry.id
        let prompt = Self.stylePrompt(name: entry.name, serving: entry.servingDescription)

        Task {
            defer {
                inFlightKeys.remove(key)
                generating.remove(entryID)
            }
            guard let image = await Self.generate(prompt: prompt) else { return }
            self.persist(image, key: key)
            self.images[key] = image
            if let fresh = self.store.entry(id: entryID) {
                fresh.imageFile = key
                self.store.save()
            }
        }
    }

    func image(for entry: FoodEntry) -> UIImage? {
        images[Self.cacheKey(for: entry.name)]
    }

    func isGenerating(_ entry: FoodEntry) -> Bool {
        generating.contains(entry.id)
    }

    // MARK: The locked shoot

    static func stylePrompt(name: String, serving: String) -> String {
        """
        Overhead studio photograph of \(name) (\(serving)), plated with care on a small \
        handmade warm-grey ceramic plate, perfectly centered, on a dark umber linen \
        tablecloth. Soft diffused window light from the upper left, one gentle soft \
        shadow. Editorial food-magazine minimalism: muted warm tones, restrained styling, \
        faint film grain, square composition, generous negative space around the plate. \
        No hands, no text, no cutlery, no props besides the single plate.
        """
    }

    static func cacheKey(for name: String) -> String {
        let normalized = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        let short = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(normalized.prefix(40))-\(short).jpg"
    }

    // MARK: Generation (Gemini generateContent, inline base64 image out)

    private static func generate(prompt: String) async -> UIImage? {
        guard let apiKey = KeyVault.get(.gemini) else { return nil }

        for model in models {
            var body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
            ]
            // Newest model takes an explicit image config; older one is happier
            // with the plain text->image default.
            if model.hasPrefix("gemini-3") {
                body["generationConfig"] = [
                    "responseModalities": ["IMAGE"],
                    "imageConfig": ["aspectRatio": "1:1"],
                ]
            } else {
                body["generationConfig"] = ["responseModalities": ["TEXT", "IMAGE"]]
            }

            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                if let image = decodeInlineImage(from: data) { return image }
            } catch {
                continue
            }
        }
        return nil
    }

    private static func decodeInlineImage(from data: Data) -> UIImage? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else { return nil }

        for part in parts {
            // The API uses camelCase; be tolerant of snake_case too.
            let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
            guard let b64 = inline?["data"] as? String,
                  let imageData = Data(base64Encoded: b64),
                  let image = UIImage(data: imageData)
            else { continue }
            return downscale(image, maxDimension: 1024)
        }
        return nil
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    // MARK: Disk cache

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("FoodImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadFromDisk(_ key: String) -> UIImage? {
        let url = Self.cacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func persist(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        try? data.write(to: Self.cacheDirectory.appendingPathComponent(key), options: .atomic)
    }
}
