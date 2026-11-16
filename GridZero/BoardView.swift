import SwiftUI
import GridZeroCore

struct BoardView: View {
    @Bindable var model: GameModel
    let game: Game
    let palette: Palette
    var hiddenValues: Set<Int> = []
    var rejectionPulse: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width / 9
            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 9), spacing: 0) {
                    ForEach(0..<81, id: \.self) { index in
                        Button {
                            model.selected = index
                            model.feedback()
                        } label: {
                            cell(index, side: side)
                                .modifier(CellShake(animatableData: model.errorCell == index ? rejectionPulse : 0))
                                .frame(width: side, height: side)
                                .background(background(index))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cell-\(index)")
                        .accessibilityLabel(accessibilityLabel(index))
                        .accessibilityValue(model.selected == index ? "Selected" : "")
                        .accessibilityHint(game.puzzle.givens[index] == 0 ? "Select, then choose a number below the board" : "Starting clue, cannot be changed")
                    }
                }
                Canvas { context, size in
                    for line in 0...9 {
                        let heavy = line % 3 == 0
                        let width: CGFloat = heavy ? 1.5 : 0.5
                        let offset = min(size.width - width / 2, max(width / 2, CGFloat(line) * size.width / 9))
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: 0)); path.addLine(to: CGPoint(x: offset, y: size.height))
                        path.move(to: CGPoint(x: 0, y: offset)); path.addLine(to: CGPoint(x: size.width, y: offset))
                        context.stroke(path, with: .color(heavy ? palette.strongLine : palette.line), lineWidth: width)
                    }
                }
                .allowsHitTesting(false)
                if let selected = model.selected {
                    Rectangle().strokeBorder(model.errorCell == selected ? palette.error : palette.accent, lineWidth: 2)
                        .frame(width: side, height: side)
                        .position(x: CGFloat(selected % 9) * side + side / 2,
                                  y: CGFloat(selected / 9) * side + side / 2)
                        .modifier(CellShake(animatableData: model.errorCell == selected ? rejectionPulse : 0))
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku board")
    }

    @ViewBuilder private func cell(_ index: Int, side: CGFloat) -> some View {
        let value = game.board.values[index]
        let given = game.puzzle.givens[index] != 0
        if value != 0 {
            Text("\(value)")
                .font(.system(size: side * 0.57, weight: given ? .medium : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.checkedCells.contains(index) ? palette.error : given ? palette.ink : palette.accent)
                .opacity(hiddenValues.contains(index) ? 0 : 1)
        } else {
            VStack(spacing: 0) {
                ForEach(0..<3) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { column in
                            let digit = row * 3 + column + 1
                            Text(game.board.notes[index] & (1 << digit) != 0 ? "\(digit)" : " ")
                                .font(.system(size: side * 0.22, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .padding(side * 0.08)
        }
    }
    private func background(_ index: Int) -> Color {
        if model.errorCell == index || model.checkedCells.contains(index) { return palette.error.opacity(0.14) }
        guard let selected = model.selected else { return palette.paper }
        if selected == index { return palette.accent.opacity(0.17) }
        if model.preferences.highlightMatching, game.board.values[selected] != 0,
           game.board.values[index] == game.board.values[selected] { return palette.accent.opacity(0.13) }
        if model.preferences.highlightPeers && Sudoku.peers[selected].contains(index) { return palette.accent.opacity(0.045) }
        return palette.paper
    }
    private func accessibilityLabel(_ index: Int) -> String {
        let location = "Row \(index / 9 + 1), column \(index % 9 + 1)"
        if game.board.values[index] != 0 {
            return "\(location), \(game.board.values[index])\(game.puzzle.givens[index] != 0 ? ", starting clue" : "")\(model.checkedCells.contains(index) ? ", incorrect" : "")"
        }
        let notes = Sudoku.digits(game.board.notes[index]).map(String.init).joined(separator: ", ")
        return "\(location), empty\(notes.isEmpty ? "" : ", notes: \(notes)")\(model.errorCell == index ? ", incorrect entry" : "")"
    }
}
