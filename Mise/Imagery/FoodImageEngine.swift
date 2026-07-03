import SwiftUI
import CryptoKit
import Observation

/// Generates and caches the studio food photography.
///
/// Provider chain, best plate first:
///  1. OpenAI `gpt-image-1` family with `background: "transparent"` — true
///     alpha cutouts, so plates float directly on Mise's own surfaces with a
///     real drop shadow. This is what makes the catalog image-centric.
///  2. Gemini (opaque square) — shown circle-cropped so it still reads as a
///     plate.
///  3. Neither key → the emoji plate.
///
/// Everything persists as PNG (alpha preserved), keyed by normalized food
/// name so "banana" today reuses last week's banana. One locked style prompt
/// keeps every plate looking like a single magazine shoot.
@MainActor
@Observable
final class FoodImageEngine {

    /// Loaded images keyed by cache filename.
    private(set) var images: [String: UIImage] = [:]
    /// Entry ids currently waiting on generation (drives the still-life placeholder).
    private(set) var generating: Set<UUID> = []

    private var inFlightKeys: Set<String> = []
    private let store: Store

    private static let openAIModels = ["gpt-image-1-mini", "gpt-image-1"]
    private static let geminiModels = ["gemini-3.1-flash-image", "gemini-2.5-flash-image"]

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
        guard KeyVault.hasOpenAIKey || KeyVault.hasGeminiKey, !inFlightKeys.contains(key) else { return }

        inFlightKeys.insert(key)
        generating.insert(entry.id)
        let entryID = entry.id
        let name = entry.name
        let serving = entry.servingDescription

        Task {
            defer {
                inFlightKeys.remove(key)
                generating.remove(entryID)
            }
            guard let image = await Self.generate(name: name, serving: serving) else { return }
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

    /// True when the image carries real transparency (a cutout plate).
    static func isCutout(_ image: UIImage) -> Bool {
        guard let alpha = image.cgImage?.alphaInfo else { return false }
        switch alpha {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    // MARK: The locked shoot

    /// Cutout brief (OpenAI, transparent): plate only, nothing else.
    static func cutoutPrompt(name: String, serving: String) -> String {
        """
        A single serving of \(name) (\(serving)) plated with restraint on a small \
        handmade warm-grey stoneware plate, photographed from directly above. \
        Studio food photography: soft diffused light from the upper left, muted warm \
        tones, editorial magazine minimalism, faint film grain. The round plate is \
        perfectly centered and fills ~85% of the frame. Isolated cutout on a fully \
        transparent background — no table, no cloth, no cast shadow outside the \
        plate, no hands, no text, no cutlery. Only the plate and the food.
        """
    }

    /// Opaque brief (Gemini fallback): same shoot, dark linen surface.
    static func opaquePrompt(name: String, serving: String) -> String {
        """
        Overhead studio photograph of \(name) (\(serving)), plated with care on a \
        small handmade warm-grey stoneware plate, perfectly centered, on a dark \
        umber linen tablecloth. Soft diffused window light from the upper left, one \
        gentle soft shadow. Editorial food-magazine minimalism: muted warm tones, \
        restrained styling, faint film grain, square composition. No hands, no text, \
        no cutlery, no props besides the single plate.
        """
    }

    static func cacheKey(for name: String) -> String {
        let normalized = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        let short = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        // v2: PNG + cutout era. Old v1 JPEGs simply orphan and regenerate.
        return "\(normalized.prefix(40))-\(short)-v2.png"
    }

    // MARK: Generation

    private static func generate(name: String, serving: String) async -> UIImage? {
        if KeyVault.hasOpenAIKey,
           let cutout = await generateOpenAI(prompt: cutoutPrompt(name: name, serving: serving)) {
            return cutout
        }
        if KeyVault.hasGeminiKey,
           let opaque = await generateGemini(prompt: opaquePrompt(name: name, serving: serving)) {
            return opaque
        }
        return nil
    }

    /// OpenAI Images API — native transparent background, base64 PNG out.
    private static func generateOpenAI(prompt: String) async -> UIImage? {
        guard let apiKey = KeyVault.get(.openai),
              let url = URL(string: "https://api.openai.com/v1/images/generations") else { return nil }

        for model in openAIModels {
            let body: [String: Any] = [
                "model": model,
                "prompt": prompt,
                "n": 1,
                "size": "1024x1024",
                "quality": "medium",
                "background": "transparent",
                "output_format": "png",
            ]
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let items = json["data"] as? [[String: Any]],
                    let b64 = items.first?["b64_json"] as? String,
                    let imageData = Data(base64Encoded: b64),
                    let image = UIImage(data: imageData)
                else { continue }
                return downscale(image, maxDimension: 1024)
            } catch {
                continue
            }
        }
        return nil
    }

    /// Gemini generateContent — inline base64 image out (opaque).
    private static func generateGemini(prompt: String) async -> UIImage? {
        guard let apiKey = KeyVault.get(.gemini) else { return nil }

        for model in geminiModels {
            var body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
            ]
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
                if let image = decodeGeminiInline(from: data) { return image }
            } catch {
                continue
            }
        }
        return nil
    }

    private static func decodeGeminiInline(from data: Data) -> UIImage? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else { return nil }

        for part in parts {
            let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
            guard let b64 = inline?["data"] as? String,
                  let imageData = Data(base64Encoded: b64),
                  let image = UIImage(data: imageData)
            else { continue }
            return downscale(image, maxDimension: 1024)
        }
        return nil
    }

    /// Downscale preserving alpha (renderer format is non-opaque).
    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    // MARK: Disk cache (PNG — alpha preserved)

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
        guard let data = image.pngData() else { return }
        try? data.write(to: Self.cacheDirectory.appendingPathComponent(key), options: .atomic)
    }
}
