import Foundation

/// Finds bundled resources: first in the test bundle, then next to the sources (Simulator / Linux).
enum TestResources {
    private final class Marker {}

    static func url(_ name: String, _ ext: String, file: StaticString = #filePath) -> URL? {
        #if canImport(ObjectiveC)
        if let u = Bundle(for: Marker.self).url(forResource: name, withExtension: ext) { return u }
        #endif
        let here = URL(fileURLWithPath: "\(file)")
        let candidate = here.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources").appendingPathComponent("\(name).\(ext)")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static let dictionary: WordDictionary? = {
        guard let a = url("wordle_allowed", "txt"), let b = url("wordle_answers", "txt") else { return nil }
        return WordDictionary(allowedURL: a, answersURL: b)
    }()

    static let chessBank: ChessPuzzleBank? = {
        guard let u = url("chess_puzzles", "json"), let d = try? Data(contentsOf: u) else { return nil }
        return ChessPuzzleBank(data: d)
    }()
}
