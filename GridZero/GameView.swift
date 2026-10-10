import SwiftUI
import GridZeroCore
import Combine
import UIKit

struct GameView: View {
    @Bindable var model: GameModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNewGame = false
    @State private var showSettings = false
    @State private var showRetry = false
    @State private var boardFrame: CGRect = .zero
    @State private var keyFrames: [Int: CGRect] = [:]
    @State private var flights: [EntryFlight] = []
    @State private var rejectionPulse: CGFloat = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var palette: Palette { Palette(theme: model.preferences.theme, dark: colorScheme == .dark) }

    var body: some View {
        GeometryReader { geometry in
            let layout = GameplayLayout(size: geometry.size, isTablet: UIDevice.current.userInterfaceIdiom == .pad)
            ZStack(alignment: .topLeading) {
                header.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("game-header").gameRegion(layout.header)
                if let game = model.game {
                    metadata(game, layout: layout)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("game-metadata").gameRegion(layout.metadata)
                    BoardView(model: model, game: game, palette: palette,
                              hiddenValues: Set(flights.filter(\.accepted).map(\.index)), rejectionPulse: rejectionPulse)
                        .frame(width: layout.board.width, height: layout.board.height)
                        .accessibilityIdentifier("board-frame")
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("game")) } action: { boardFrame = $0 }
                        .position(x: layout.board.midX, y: layout.board.midY)
                    controls(game, layout: layout)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("game-tools").gameRegion(layout.tools)
                    keypad(game, layout: layout)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("game-keypad").gameRegion(layout.keypad)
                    footer(game).gameRegion(layout.status)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.3x3").font(.system(size: 54, weight: .ultraLight))
                        if model.generating { ProgressView().padding() }
                        if let error = model.generationError {
                            Text(error).font(.callout).padding()
                            Button("Choose a puzzle") { showNewGame = true }.buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: min(480, geometry.size.width - 32), maxHeight: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                ForEach(flights) { flight in
                    Text("\(flight.digit)")
                        .font(.system(size: flight.fontSize, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(flight.rejected ? palette.error : palette.accent)
                        .scaleEffect(flight.scale)
                        .opacity(flight.opacity)
                        .position(flight.position)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "game")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game-surface")
            .onChange(of: geometry.size) { _, _ in finishFlights() }
        }
        .background(palette.paper)
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .sheet(isPresented: $showNewGame) { NewGameView(model: model) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $model.showCompletion) {
            completion.presentationDetents([.medium])
        }
        .alert("Time for a fresh start.", isPresented: $model.showStrikeOut) {
            Button("Retry This Puzzle") { flights = []; model.retry() }
            Button("Continue in Classic") { flights = []; model.continueClassic() }
            Button("New Puzzle") { showNewGame = true }
        } message: {
            Text("You've reached this game's \(model.game?.strikeLimit ?? 3)-strike limit. Your board is saved.")
        }
        .alert("Restart this puzzle?", isPresented: $showRetry) {
            Button("Restart", role: .destructive) { flights = []; model.retry() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your entries, notes, strikes, and time will be reset.") }
        .alert(model.notice?.title ?? "", isPresented: Binding(
            get: { model.notice != nil },
            set: { if !$0 { model.notice = nil } }
        )) {
            Button("OK", role: .cancel) { model.notice = nil }
        } message: {
            Text(model.notice?.message ?? "")
        }
        .onReceive(timer) { _ in
            model.tick(active: scenePhase == .active && !showNewGame && !showSettings && !model.showCompletion)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishFlights(); model.pause() } else { model.clock = Date() }
        }
        .onChange(of: showNewGame) { _, _ in finishFlights(); model.pause() }
        .onChange(of: showSettings) { _, _ in finishFlights(); model.pause() }
        .onChange(of: model.game?.puzzle.id) { _, _ in flights = [] }
        .onChange(of: reduceMotion) { _, _ in finishFlights() }
        .task {
            if model.game == nil {
                _ = await model.start(difficulty: .easy, mode: model.preferences.mode, source: .collection, empty: 45)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("GridZero").font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-0.7)
            Spacer()
            Menu {
                Button("New Puzzle", systemImage: "plus") { showNewGame = true }
                Button("Settings", systemImage: "slider.horizontal.3") { showSettings = true }
                if model.game?.mode == .classic {
                    Button("Check Board", systemImage: "checkmark.circle") { model.checkBoard() }
                }
                if model.preferences.allowAutofill {
                    Button("Fill Notes", systemImage: "pencil.and.list.clipboard") { model.fillNotes() }
                        .disabled(model.game?.finished == true || model.game?.isOut == true)
                }
                Button("Redo", systemImage: "arrow.uturn.forward") { flights = []; model.redo() }
                    .disabled(model.game?.canRedo != true)
                Button("Restart Puzzle", systemImage: "arrow.counterclockwise") { showRetry = true }
                    .disabled(model.game == nil)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18)).frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle())
            }
            .accessibilityLabel("Game menu")
        }
    }

    private func metadata(_ game: Game, layout: GameplayLayout) -> some View {
        HStack(alignment: .center) {
            if layout.tight {
                HStack(spacing: 6) {
                    difficultyLabel(game)
                    Text("·").foregroundStyle(palette.secondary)
                    Text(game.mode.title).font(.system(size: 12)).foregroundStyle(palette.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    difficultyLabel(game)
                    Text(game.mode.title).font(.system(size: 12)).foregroundStyle(palette.secondary)
                }
            }
            Spacer()
            if model.preferences.showTimer {
                Text(time(game.elapsed)).monospacedDigit().font(.system(size: 13)).foregroundStyle(palette.secondary)
                    .accessibilityLabel("Elapsed time \(time(game.elapsed))")
            }
            if game.mode == .challenge {
                if game.strikeLimit > 0 && game.strikeLimit <= 5 {
                    HStack(spacing: 6) {
                        ForEach(0..<game.strikeLimit, id: \.self) { strike in
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(strike < game.strikes ? palette.error : palette.line.opacity(0.65))
                                .scaleEffect(strike < game.strikes ? 1 : 0.85)
                                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55), value: game.strikes)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(game.strikes) of \(game.strikeLimit) strikes")
                    .accessibilityIdentifier("strikes")
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(game.strikes > 0 ? palette.error : palette.secondary)
                        Text("\(game.strikes)\(game.strikeLimit == 0 ? "" : " / \(game.strikeLimit)")")
                            .font(.system(size: 12)).foregroundStyle(palette.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(game.strikeLimit == 0 ? "\(game.strikes) strikes" : "\(game.strikes) of \(game.strikeLimit) strikes")
                    .accessibilityIdentifier("strikes")
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func difficultyLabel(_ game: Game) -> some View {
        Text(game.puzzle.difficulty == .custom ? "Custom · \(game.puzzle.givens.filter { $0 == 0 }.count) empty" : game.puzzle.difficulty.title)
            .font(.system(size: 15, weight: .semibold))
    }

    private func controls(_ game: Game, layout: GameplayLayout) -> some View {
        HStack(spacing: layout.toolSpacing) {
            tool("Undo", symbol: "arrow.uturn.backward", enabled: game.canUndo, active: false, layout: layout) { flights = []; model.undo() }
            tool("Erase", symbol: "eraser", enabled: canEnter(game), active: false, layout: layout) { flights = []; model.erase() }
            tool("Notes", symbol: model.pencil ? "pencil.circle.fill" : "pencil", enabled: !game.finished && !game.isOut,
                 active: model.pencil, layout: layout) { flights = []; model.pencil.toggle(); model.feedback() }
        }
    }
    private func tool(_ title: String, symbol: String, enabled: Bool, active: Bool, layout: GameplayLayout, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: layout.compact ? 18 : 20))
                Text(title).font(.system(size: 12, weight: active ? .semibold : .regular))
            }
            .frame(width: layout.toolWidth, height: layout.toolHeight)
            .foregroundStyle(active ? palette.accent : palette.secondary)
            .background(active ? palette.accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityIdentifier("tool-\(title.lowercased())")
        .accessibilityValue(title == "Notes" ? (active ? "On" : "Off") : "")
    }

    private func keypad(_ game: Game, layout: GameplayLayout) -> some View {
        GeometryReader { geometry in
            let pitch = geometry.size.width / 5
            VStack(spacing: layout.keyGap) {
                HStack(spacing: 0) {
                    ForEach([1, 3, 5, 7, 9], id: \.self) { digit in number(digit, game: game, pitch: pitch, layout: layout) }
                }
                HStack(spacing: 0) {
                    ForEach([2, 4, 6, 8], id: \.self) { digit in number(digit, game: game, pitch: pitch, layout: layout) }
                }.frame(maxWidth: .infinity)
            }
        }
        .frame(height: layout.keypad.height)
    }
    private func number(_ digit: Int, game: Game, pitch: CGFloat, layout: GameplayLayout) -> some View {
        Button { enter(digit, fontSize: layout.keyFontSize) } label: {
            Text("\(digit)").font(.system(size: layout.keyFontSize, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(palette.accent)
                .frame(width: layout.keyWidth, height: layout.keyHeight)
                .background(model.pencil ? palette.accent.opacity(0.1) : palette.surface,
                            in: RoundedRectangle(cornerRadius: 17))
                .overlay {
                    if model.pencil { RoundedRectangle(cornerRadius: 17).strokeBorder(palette.accent.opacity(0.35)) }
                }
                .opacity(game.board.values.filter { $0 == digit }.count >= 9 ? 0.45 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeyPressStyle())
        .frame(width: pitch)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("game")) } action: { keyFrames[digit] = $0 }
        .disabled(!canEnter(game))
        .opacity(canEnter(game) ? 1 : 0.35)
        .accessibilityLabel(model.pencil ? "Toggle note \(digit)" : "Enter \(digit)")
        .accessibilityIdentifier("number-\(digit)")
    }

    private func footer(_ game: Game) -> some View {
        HStack {
            if let error = model.saveError {
                Text(error).foregroundStyle(palette.error)
            } else if model.errorCell != nil {
                Label("Not quite. Try another number.", systemImage: "xmark.circle.fill")
                    .foregroundStyle(palette.error)
                    .accessibilityIdentifier("wrong-entry-feedback")
            } else if game.finished {
                Button("Puzzle complete", systemImage: "checkmark") { model.showCompletion = true }
            } else if game.isOut {
                Button("Continue in Classic") { model.continueClassic() }
            } else if model.pencil {
                Text("Pencil notes are on").foregroundStyle(palette.accent)
            }
        }
        .font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.75)
    }
    private func canEnter(_ game: Game) -> Bool {
        guard let selected = model.selected else { return false }
        return game.puzzle.givens[selected] == 0 && !game.finished && !game.isOut
    }

    private func enter(_ digit: Int, fontSize: CGFloat) {
        guard let index = model.selected, let game = model.game else { return }
        // Pencil marks and Reduce Motion retain immediate feedback without travel.
        guard !model.pencil, !reduceMotion, let key = keyFrames[digit], boardFrame.width > 0 else {
            model.enter(digit)
            return
        }
        let result = model.enter(digit, deferFeedback: true)
        guard result != .ignored else { return }
        let side = boardFrame.width / 9
        let source = CGPoint(x: key.midX, y: key.midY)
        let target = CGPoint(x: boardFrame.minX + CGFloat(index % 9) * side + side / 2,
                             y: boardFrame.minY + CGFloat(index / 9) * side + side / 2)
        let accepted = result != .strike
        let flight = EntryFlight(digit: digit, index: index, source: source, target: target,
                                 accepted: accepted, position: source, fontSize: fontSize)
        flights.removeAll { $0.index == index }
        flights.append(flight)
        Task { @MainActor in
            // Render the copy at the key before changing its animated destination.
            try? await Task.sleep(for: .milliseconds(16))
            guard let position = flights.firstIndex(where: { $0.id == flight.id }) else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                flights[position].position = accepted ? target : CGPoint(x: target.x, y: target.y + side * 0.2)
                flights[position].fontSize = side * 0.57
            }
            try? await Task.sleep(for: .milliseconds(220))
            guard model.game?.puzzle.id == game.puzzle.id,
                  let position = flights.firstIndex(where: { $0.id == flight.id }) else { return }
            if accepted {
                flights.removeAll { $0.id == flight.id }
                model.presentEntryFeedback(result, at: index)
            } else {
                model.presentEntryFeedback(result, at: index, showOutcome: false)
                flights[position].rejected = true
                withAnimation(.linear(duration: 0.24)) { rejectionPulse += 1 }
                try? await Task.sleep(for: .milliseconds(70))
                guard let position = flights.firstIndex(where: { $0.id == flight.id }) else { return }
                withAnimation(.easeIn(duration: 0.24)) {
                    flights[position].position = source
                    flights[position].fontSize = fontSize
                    flights[position].scale = 0.75
                    flights[position].opacity = 0
                }
                try? await Task.sleep(for: .milliseconds(240))
                guard flights.contains(where: { $0.id == flight.id }) else { return }
                flights.removeAll { $0.id == flight.id }
                model.finishEntryPresentation()
            }
        }
    }

    private func finishFlights() {
        guard !flights.isEmpty else { return }
        flights = []
        model.finishEntryPresentation()
    }

    private var completion: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal").font(.system(size: 42, weight: .light)).foregroundStyle(palette.accent)
            Text("Beautifully solved.").font(.title2.weight(.medium))
            if let game = model.game {
                Text("\(game.puzzle.difficulty.title) · \(game.mode.title)\(model.preferences.showTimer ? " · \(time(game.elapsed))" : "")")
                    .font(.subheadline).foregroundStyle(palette.secondary)
            }
            Button("Another puzzle") { model.showCompletion = false; showNewGame = true }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Button("Enjoy the moment") { model.showCompletion = false }.font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.paper)
    }
    private func time(_ elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}
