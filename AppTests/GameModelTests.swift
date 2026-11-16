import XCTest
import GridZeroCore
@testable import GridZero

private func fixture(_ id: String = "fixture") -> Puzzle {
    let givens = "530070000600195000098000060800060003400803001700020006060000280000419005000080079".compactMap(\.wholeNumberValue)
    let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179".compactMap(\.wholeNumberValue)
    return Puzzle(id: id, givens: givens, solution: solution,
                  difficulty: .easy, source: .collection)
}

private actor MemoryStore: GameStorage {
    var saved: SaveEnvelope?
    var writes: [SaveEnvelope] = []
    var failRead = false
    var failWrite = false
    private var blockFirstWrite: Bool
    private var release: CheckedContinuation<Void, Never>?
    private let started = AsyncStream<Void>.makeStream()

    init(game: Game? = nil, blockFirstWrite: Bool = false, failRead: Bool = false) {
        saved = game.map { SaveEnvelope(game: $0, played: [$0.puzzle.id]) }
        self.blockFirstWrite = blockFirstWrite
        self.failRead = failRead
    }
    func load() throws -> SaveEnvelope? {
        if failRead { throw CocoaError(.fileReadNoPermission) }
        return saved
    }
    func write(_ save: SaveEnvelope, preservingOriginal: Bool) async throws {
        writes.append(save)
        if blockFirstWrite {
            blockFirstWrite = false
            started.continuation.yield(())
            await withCheckedContinuation { release = $0 }
        }
        if failWrite { throw CocoaError(.fileWriteOutOfSpace) }
        saved = save
    }
    func waitForWrite() async { for await _ in started.stream { break } }
    func resumeWrite() { release?.resume(); release = nil }
    func setReadFailure(_ value: Bool) { failRead = value }
    func setWriteFailure(_ value: Bool) { failWrite = value }
}

private final class GenerationGate: Sendable {
    let started = AsyncStream<Void>.makeStream()
    let resume = DispatchSemaphore(value: 0)
    func block() {
        started.continuation.yield(())
        resume.wait()
    }
    func waitUntilStarted() async { for await _ in started.stream { break } }
}

@MainActor
final class GameModelTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            suite = "GridZeroModelTests.\(UUID())"
            defaults = UserDefaults(suiteName: suite)!
        }
    }

    override func tearDown() async throws {
        await MainActor.run { defaults.removePersistentDomain(forName: suite) }
        try await super.tearDown()
    }

    private func model(storage: any GameStorage = MemoryStore(),
                       uptime: @escaping () -> TimeInterval = { 0 },
                       loader: @escaping GameModel.PuzzleLoader = { _, _, _, _ in fixture() }) -> GameModel {
        GameModel(defaults: defaults, storage: storage, uptime: uptime,
                  loadPuzzle: loader, entryFeedback: { _, _, _, _ in })
    }

    func testPreferencesRepairFieldsIndependentlyAndRoundTrip() throws {
        let json = """
        {"difficulty":"hard","source":"generated","mode":"classic","appearance":"unknown",
         "showTimer":true,"haptics":"bad","strikeLimit":999,"customEmpty":19,"lightAt":-1}
        """
        let prefs = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(prefs.difficulty, .hard)
        XCTAssertEqual(prefs.source, .generated)
        XCTAssertEqual(prefs.mode, .classic)
        XCTAssertEqual(prefs.appearance, .system)
        XCTAssertTrue(prefs.showTimer)
        XCTAssertTrue(prefs.haptics)
        XCTAssertEqual(prefs.strikeLimit, 3)
        XCTAssertEqual(prefs.customEmpty, 45)
        XCTAssertEqual(prefs.lightAt, 420)
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(restored.difficulty, .hard)
        XCTAssertEqual(restored.mode, .classic)
        XCTAssertTrue(restored.showTimer)
    }

    func testReadFailureBlocksAutomaticReplacementAndRetryRestores() async {
        var original = Game(puzzle: fixture(), mode: .classic, strikeLimit: 10)
        original.elapsed = 123.5
        original.enter(1, at: 2, pencil: true)
        let store = MemoryStore(game: original, failRead: true)
        let model = model(storage: store, loader: { _, _, _, _ in
            XCTFail("Read failure must not start a replacement")
            return fixture()
        })
        await model.bootstrap()
        XCTAssertNil(model.game)
        XCTAssertNotNil(model.recoveryError)
        XCTAssertTrue(model.showRecoveryAlert)
        let initialWrites = await store.writes
        XCTAssertTrue(initialWrites.isEmpty)
        await store.setReadFailure(false)
        await model.restore()
        XCTAssertNil(model.recoveryError)
        XCTAssertFalse(model.showRecoveryAlert)
        XCTAssertEqual(model.game?.board, original.board)
        XCTAssertEqual(model.game?.elapsed, 123.5)
        XCTAssertEqual(model.game?.strikeLimit, 10)
        XCTAssertEqual(model.game?.undoStack, original.undoStack)
    }

    func testMissingSaveUsesRememberedChoicesAndFailureDoesNotCommit() async throws {
        var prefs = Preferences()
        prefs.difficulty = .hard; prefs.source = .generated; prefs.mode = .classic
        defaults.set(try JSONEncoder().encode(prefs), forKey: "preferences.v1")
        let model = model(loader: { difficulty, source, _, _ in
            XCTAssertEqual(difficulty, .hard)
            XCTAssertEqual(source, .generated)
            throw PuzzleError.generationLimit
        })
        await model.bootstrap()
        XCTAssertNil(model.game)
        XCTAssertNotNil(model.generationError)
        XCTAssertNil(model.recoveryError)
        XCTAssertEqual(model.preferences.difficulty, .hard)
        XCTAssertEqual(model.preferences.source, .generated)
    }

    func testCancelledAndStaleGenerationCannotReplaceGameOrPreferences() async {
        let gate = GenerationGate()
        let original = Game(puzzle: fixture("original"))
        let model = model(storage: MemoryStore(game: original), loader: { difficulty, _, _, _ in
            if difficulty == .expert { gate.block() }
            return fixture(difficulty.rawValue)
        })
        await model.bootstrap()
        let old = Task { await model.start(difficulty: .expert, mode: .classic, source: .generated, empty: 60) }
        await gate.waitUntilStarted()
        model.cancelGeneration()
        XCTAssertEqual(model.game?.puzzle.id, "original")
        XCTAssertEqual(model.preferences.difficulty, .medium)
        let newer = await model.start(difficulty: .easy, mode: .challenge, source: .collection, empty: 45)
        XCTAssertTrue(newer)
        gate.resume.signal()
        let stale = await old.value
        XCTAssertFalse(stale)
        XCTAssertEqual(model.game?.puzzle.id, "easy")
        XCTAssertEqual(model.preferences.difficulty, .easy)
        XCTAssertNil(model.generationError)
        await model.flushSaves()
    }

    func testFailedReplacementKeepsBoardHistoryAndPreferences() async {
        var original = Game(puzzle: fixture(), mode: .classic, strikeLimit: 10)
        original.enter(1, at: 2, pencil: true)
        original.elapsed = 25
        let model = model(storage: MemoryStore(game: original),
                          loader: { _, _, _, _ in throw PuzzleError.generationLimit })
        await model.bootstrap()
        let result = await model.start(difficulty: .custom, mode: .challenge, source: .generated, empty: 60)
        XCTAssertFalse(result)
        XCTAssertEqual(model.game?.board, original.board)
        XCTAssertEqual(model.game?.undoStack, original.undoStack)
        XCTAssertEqual(model.game?.elapsed, original.elapsed)
        XCTAssertEqual(model.game?.mode, .classic)
        XCTAssertEqual(model.preferences.difficulty, .medium)
        XCTAssertEqual(model.preferences.source, .collection)
        XCTAssertEqual(model.preferences.customEmpty, 45)
        XCTAssertNotNil(model.generationError)
    }

    func testParentTaskCancellationDoesNotCommit() async {
        let gate = GenerationGate()
        let model = model(storage: MemoryStore(game: Game(puzzle: fixture("original"))),
                          loader: { _, _, _, _ in gate.block(); return fixture("replacement") })
        await model.bootstrap()
        let request = Task { await model.start(difficulty: .expert, mode: .classic, source: .generated, empty: 60) }
        await gate.waitUntilStarted()
        request.cancel()
        gate.resume.signal()
        let result = await request.value
        XCTAssertFalse(result)
        XCTAssertFalse(model.generating)
        XCTAssertEqual(model.game?.puzzle.id, "original")
        XCTAssertEqual(model.preferences.difficulty, .medium)
    }

    func testCancelledBootstrapCanBeRetried() async {
        let gate = GenerationGate()
        let model = model(loader: { _, _, _, _ in gate.block(); return fixture() })
        let startup = Task { await model.bootstrap() }
        await gate.waitUntilStarted()
        startup.cancel()
        gate.resume.signal()
        await startup.value
        XCTAssertNil(model.game)
        XCTAssertNil(model.recoveryError)
        XCTAssertNil(model.generationError)
        gate.resume.signal()
        await model.bootstrap()
        XCTAssertEqual(model.game?.puzzle.id, "fixture")
        await model.flushSaves()
    }

    func testTimerCheckpointsAndExcludesPausedIntervalsWithoutLosingFractions() async {
        var now = 100.0
        let store = MemoryStore(game: Game(puzzle: fixture()))
        let model = model(storage: store, uptime: { now })
        await model.bootstrap()
        model.setActive(true)
        now += 15.25
        model.tick()
        await model.flushSaves()
        let checkpoint = await store.saved
        XCTAssertEqual(checkpoint?.game.elapsed, 15.25)
        now += 0.5
        model.pause()
        now += 60
        model.tick()
        XCTAssertEqual(model.game?.elapsed, 15.75)
        model.setActive(true)
        now += 0.25
        model.checkBoard()
        now += 30
        model.tick()
        XCTAssertEqual(model.game?.elapsed, 16)
        model.notice = nil
        model.setActive(true)
        now += 1
        model.pause()
        await model.flushSaves()
        let saved = await store.saved
        XCTAssertEqual(saved?.game.elapsed, 17)
        model.retry()
        XCTAssertEqual(model.game?.elapsed, 0)
        await model.flushSaves()
    }

    func testSlowWritesDoNotBlockMovesAndRemainOrdered() async {
        let store = MemoryStore(game: Game(puzzle: fixture()), blockFirstWrite: true)
        let model = model(storage: store)
        await model.bootstrap()
        model.selected = 2; model.pencil = true
        model.enter(1)
        await store.waitForWrite()
        model.enter(2)
        model.enter(3)
        XCTAssertEqual(model.game?.board.notes[2], 14)
        let pending = await store.writes
        XCTAssertEqual(pending.count, 1)
        await store.resumeWrite()
        await model.flushSaves()
        let writes = await store.writes
        XCTAssertEqual(writes.map { $0.game.board.notes[2] }, [2, 6, 14])
        let persisted = await store.saved
        XCTAssertEqual(persisted?.game.board, model.game?.board)
    }

    func testWriteFailureIsVisibleAndClearsOnlyAfterSuccessfulWrite() async {
        let store = MemoryStore(game: Game(puzzle: fixture()))
        await store.setWriteFailure(true)
        let model = model(storage: store)
        await model.bootstrap()
        model.selected = 2; model.pencil = true
        model.enter(1)
        await model.flushSaves()
        XCTAssertNotNil(model.saveError)
        XCTAssertEqual(model.game?.board.notes[2], 2)
        await store.setWriteFailure(false)
        model.save()
        await model.flushSaves()
        XCTAssertNil(model.saveError)
        let saved = await store.saved
        XCTAssertEqual(saved?.game.board.notes[2], 2)
    }

    func testRapidInputDeliversEachStrikeBeforeAnimationCompletes() async {
        var strikes: [Int] = []
        let model = GameModel(defaults: defaults, storage: MemoryStore(game: Game(puzzle: fixture())),
                              entryFeedback: { result, count, _, _ in
            if result == .strike { strikes.append(count) }
        })
        await model.bootstrap()
        model.selected = 2
        let solution = fixture().solution[2]
        model.enter(solution % 9 + 1, deferOutcome: true)
        model.enter(solution % 9 + 1, deferOutcome: true)
        model.enter(solution, deferOutcome: true)
        XCTAssertEqual(strikes, [1, 2])
        XCTAssertEqual(model.game?.strikes, 2)
        XCTAssertEqual(model.game?.board.values[2], solution)
        model.enter(solution % 9 + 1, deferOutcome: true)
        XCTAssertEqual(strikes, [1, 2, 3])
        XCTAssertFalse(model.showStrikeOut)
        model.finishEntryPresentation()
        XCTAssertTrue(model.showStrikeOut)
        await model.flushSaves()
    }
}
