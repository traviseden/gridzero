import Foundation
import GridZeroCore

struct Preferences: Codable {
    var theme: Theme = .ink
    var appearance: Appearance = .system
    var lightAt = 7 * 60
    var darkAt = 19 * 60
    var source: PuzzleSource = .collection
    var difficulty: Difficulty = .medium
    var mode: PlayMode = .challenge
    var strikeLimit = 3
    var customEmpty = 45
    var allowAutofill = false
    var cleanupNotes = false
    var highlightPeers = true
    var highlightMatching = true
    var showTimer = false
    var haptics = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case theme, appearance, lightAt, darkAt, source, difficulty, mode, strikeLimit, customEmpty
        case allowAutofill, cleanupNotes, highlightPeers, highlightMatching, showTimer, haptics
    }

    // v1 remains readable when fields are missing or individually damaged.
    // Unknown fields are ignored, so future additions need not reset remembered choices.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, fallback: T) -> T {
            (try? values.decode(T.self, forKey: key)) ?? fallback
        }
        theme = value(.theme, fallback: theme)
        appearance = value(.appearance, fallback: appearance)
        lightAt = value(.lightAt, fallback: lightAt)
        darkAt = value(.darkAt, fallback: darkAt)
        source = value(.source, fallback: source)
        difficulty = value(.difficulty, fallback: difficulty)
        mode = value(.mode, fallback: mode)
        strikeLimit = value(.strikeLimit, fallback: strikeLimit)
        customEmpty = value(.customEmpty, fallback: customEmpty)
        allowAutofill = value(.allowAutofill, fallback: allowAutofill)
        cleanupNotes = value(.cleanupNotes, fallback: cleanupNotes)
        highlightPeers = value(.highlightPeers, fallback: highlightPeers)
        highlightMatching = value(.highlightMatching, fallback: highlightMatching)
        showTimer = value(.showTimer, fallback: showTimer)
        haptics = value(.haptics, fallback: haptics)
        if !(0..<1440).contains(lightAt) { lightAt = 7 * 60 }
        if !(0..<1440).contains(darkAt) { darkAt = 19 * 60 }
        if !(1...5).contains(strikeLimit) { strikeLimit = 3 }
        if !(20...60).contains(customEmpty) { customEmpty = 45 }
    }
}
