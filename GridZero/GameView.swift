import SwiftUI
import GridZeroCore
import Combine
import UIKit

struct GameView: View {
    @Bindable var model: GameModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var captionSize = 12.0
    @ScaledMetric(relativeTo: .caption) private var timerSize = 13.0
    @ScaledMetric(relativeTo: .subheadline) private var difficultySize = 15.0
    @ScaledMetric(relativeTo: .title2) private var titleSize = 25.0
    @State private var showNewGame = false
    @State private var showSettings = false
    @State private var showRetry = false
    @State private var boardFrame: CGRect = .zero
    @State private var keyFrames: [Int: CGRect] = [:]
    @State private var flights: [EntryFlight] = []
    @State private var rejectionPulse: CGFloat = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var palette: Palette { Palette(theme: model.preferences.theme, dark: colorScheme == .dark) }
    private var accessibleLayout: Bool { dynamicTypeSize.isAccessibilitySize }
    private var gameplayActive: Bool {
        scenePhase == .active && !showNewGame && !showSettings && !showRetry &&
        !model.showCompletion && !model.showStrikeOut && model.notice == nil &&
        !model.showRecoveryAlert && !model.loading && !model.generating &&
        model.game != nil && model.game?.finished == false && model.game?.isOut == false
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = GameplayLayout(size: geometry.size, isTablet: UIDevice.current.userInterfaceIdiom == .pad,
                                        textScale: captionSize / 12, expandedStatus: model.saveError != nil)
            ZStack(alignment: .topLeading) {
                if accessibleLayout, let game = model.game {
                    accessibleGame(game, width: geometry.size.width, layout: layout)
                } else {
                    fixedGame(layout, size: geometry.size)
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
            completion.presentationDetents(accessibleLayout ? [.large] : [.medium])
        }
        .alert("Couldn't restore your game", isPresented: $model.showRecoveryAlert) {
            Button("Retry") { Task { await model.restore() } }
            Button("New Puzzle") { showNewGame = true }
        } message: {
            Text(model.recoveryError ?? "")
        }
        .alert("Strike limit reached", isPresented: $model.showStrikeOut) {
            Button("Retry This Puzzle") { flights = []; model.retry() }
            Button("Continue in Classic") { flights = []; model.continueClassic() }
            Button("New Puzzle") { showNewGame = true }
        } message: {
            Text("\(model.game?.strikeLimit ?? 3) strikes.")
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
        .onReceive(timer) { _ in model.tick() }
        .onChange(of: gameplayActive, initial: true) { _, active in model.setActive(active) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishFlights(); model.pause() } else { model.clock = Date() }
        }
        .onChange(of: showNewGame) { _, showing in
            finishFlights()
            if !showing, model.game == nil, model.recoveryError != nil { model.showRecoveryAlert = true }
        }
        .onChange(of: showSettings) { _, _ in finishFlights() }
        .onChange(of: model.game?.puzzle.id) { _, _ in flights = [] }
        .onChange(of: reduceMotion) { _, _ in finishFlights() }
        .onDisappear { model.pause() }
        .task { await model.bootstrap() }
    }

    @ViewBuilder private func fixedGame(_ layout: GameplayLayout, size: CGSize) -> some View {
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
            if model.saveError != nil {
                ScrollView(.vertical) { footer(game).frame(maxWidth: .infinity) }.gameRegion(layout.status)
            } else {
                footer(game).gameRegion(layout.status)
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "square.grid.3x3").font(.system(size: 54, weight: .ultraLight))
                if model.generating || model.loading { ProgressView().padding() }
                if let error = model.generationError {
                    Text(error).font(.callout).padding()
                    Button("Choose a puzzle") { showNewGame = true }.buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: min(480, size.width - 32), maxHeight: size.height)
            .position(x: size.width / 2, y: size.height / 2)
        }
    }

    private func accessibleGame(_ game: Game, width: CGFloat, layout: GameplayLayout) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header.padding(.horizontal, 22)
                metadata(game, layout: layout).padding(.horizontal, 22)
                BoardView(model: model, game: game, palette: palette,
                          hiddenValues: Set(flights.filter(\.accepted).map(\.index)), rejectionPulse: rejectionPulse)
                    .frame(width: min(720, width), height: min(720, width))
                    .accessibilityIdentifier("board-frame")
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("game")) } action: {
                        if boardFrame != $0 { finishFlights() }
                        boardFrame = $0
                    }
                controls(game, layout: layout).padding(.horizontal, 18)
                keypad(game, layout: layout).frame(maxWidth: 480).padding(.horizontal, 18)
                footer(game).padding(.horizontal, 22)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("accessible-game")
    }

    private var header: some View {
        HStack {
            Text("GridZero").font(.system(size: titleSize, weight: .semibold, design: .rounded)).tracking(-0.7)
            Spacer()
            Menu {
                Button("New Puzzle", systemImage: "plus") { model.pause(); showNewGame = true }
                    .disabled(model.loading)
                Button("Settings", systemImage: "slider.horizontal.3") { model.pause(); showSettings = true }
                if model.game?.mode == .classic {
                    Button("Check Board", systemImage: "checkmark.circle") { model.checkBoard() }
                }
                if model.preferences.allowAutofill {
                    Button("Fill Notes", systemImage: "pencil.and.list.clipboard") { model.fillNotes() }
                        .disabled(model.game?.finished == true || model.game?.isOut == true)
                }
                Button("Redo", systemImage: "arrow.uturn.forward") { flights = []; model.redo() }
                    .disabled(model.game?.canRedo != true)
                Button("Restart Puzzle", systemImage: "arrow.counterclockwise") { model.pause(); showRetry = true }
                    .disabled(model.game == nil)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18)).frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle())
            }
            .accessibilityLabel("Game menu")
        }
    }

    private func metadata(_ game: Game, layout: GameplayLayout) -> some View {
        let arrangement = accessibleLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
            AnyLayout(HStackLayout(alignment: .center))
        return arrangement {
            if layout.tight && !accessibleLayout {
                HStack(spacing: 6) {
                    difficultyLabel(game)
                    Text("·").foregroundStyle(palette.secondary)
                    Text(game.mode.title).font(.system(size: captionSize)).foregroundStyle(palette.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    difficultyLabel(game)
                    Text(game.mode.title).font(.system(size: captionSize)).foregroundStyle(palette.secondary)
                }
            }
            if !accessibleLayout { Spacer() }
            if model.preferences.showTimer {
                Text(game.elapsedText).monospacedDigit().font(.system(size: timerSize)).foregroundStyle(palette.secondary)
                    .accessibilityLabel("Elapsed time \(game.elapsedText)")
                    .accessibilityIdentifier("elapsed-time")
            }
            if game.mode == .challenge {
                if game.strikeLimit > 0 && game.strikeLimit <= 5 {
                    HStack(spacing: 6) {
                        ForEach(0..<game.strikeLimit, id: \.self) { strike in
                            Image(systemName: "xmark")
                                .font(.system(size: captionSize, weight: .bold))
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
                        Image(systemName: "xmark").font(.system(size: captionSize, weight: .bold))
                            .foregroundStyle(game.strikes > 0 ? palette.error : palette.secondary)
                        Text("\(game.strikes)\(game.strikeLimit == 0 ? "" : " / \(game.strikeLimit)")")
                            .font(.system(size: captionSize)).foregroundStyle(palette.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(game.strikeLimit == 0 ? "\(game.strikes) strikes" : "\(game.strikes) of \(game.strikeLimit) strikes")
                    .accessibilityIdentifier("strikes")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(accessibleLayout ? nil : 1)
        .minimumScaleFactor(accessibleLayout ? 1 : 0.8)
    }

    private func difficultyLabel(_ game: Game) -> some View {
        Text(game.puzzle.difficulty == .custom ? "Custom · \(game.puzzle.givens.filter { $0 == 0 }.count) empty" : game.puzzle.difficulty.title)
            .font(.system(size: difficultySize, weight: .semibold))
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
                Text(title).font(.system(size: captionSize, weight: active ? .semibold : .regular))
            }
            .frame(width: accessibleLayout ? nil : layout.toolWidth, height: accessibleLayout ? nil : layout.toolHeight)
            .frame(maxWidth: accessibleLayout ? .infinity : nil, minHeight: 44)
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
        .frame(height: accessibleLayout ? max(66, captionSize * 2) * 2 + layout.keyGap : layout.keypad.height)
    }
    private func number(_ digit: Int, game: Game, pitch: CGFloat, layout: GameplayLayout) -> some View {
        Button { enter(digit, fontSize: layout.keyFontSize) } label: {
            Text("\(digit)")
                .font(.system(size: accessibleLayout ? min(pitch - 12, captionSize * 2.4) : layout.keyFontSize,
                              weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(palette.accent)
                .frame(width: accessibleLayout ? min(86, pitch - 8) : layout.keyWidth,
                       height: accessibleLayout ? max(66, captionSize * 2) : layout.keyHeight)
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
                    .accessibilityIdentifier("save-error")
            } else if model.errorCell != nil {
                Label("Incorrect number", systemImage: "xmark.circle.fill")
                    .foregroundStyle(palette.error)
                    .accessibilityIdentifier("wrong-entry-feedback")
            } else if game.finished {
                Button("Puzzle complete", systemImage: "checkmark") { model.showCompletion = true }
            } else if game.isOut {
                Button("Continue in Classic") { model.continueClassic() }
            }
        }
        .font(.system(size: captionSize))
        .fixedSize(horizontal: false, vertical: true)
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
        let result = model.enter(digit, deferOutcome: true)
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
                if flights.isEmpty { model.finishEntryPresentation() }
            } else {
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
                if flights.isEmpty { model.finishEntryPresentation() }
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
            Text("Puzzle complete").font(.title2.weight(.medium))
            if let game = model.game {
                Text("\(game.puzzle.difficulty.title) · \(game.mode.title)\(model.preferences.showTimer ? " · \(game.elapsedText)" : "")")
                    .font(.subheadline).foregroundStyle(palette.secondary)
            }
            Button("Another puzzle") { model.showCompletion = false; showNewGame = true }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Button("Done") { model.showCompletion = false }.font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.paper)
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}
