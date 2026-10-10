import SwiftUI
import GridZeroCore

struct NewGameView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty: Difficulty
    @State private var mode: PlayMode
    @State private var source: PuzzleSource
    @State private var empty: Double

    init(model: GameModel) {
        self.model = model
        _difficulty = State(initialValue: model.preferences.difficulty)
        _mode = State(initialValue: model.preferences.mode)
        _source = State(initialValue: model.preferences.source)
        _empty = State(initialValue: Double(model.preferences.customEmpty))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in Text(level.title).tag(level) }
                    }
                    .accessibilityIdentifier("difficulty-picker")
                    if difficulty == .custom {
                        HStack {
                            Text("Empty squares")
                            Spacer()
                            Text("\(Int(empty))").monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $empty, in: 20...60, step: 1).accessibilityLabel("Empty squares")
                        Text("\(81 - Int(empty)) starting clues. Always one unique solution.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(difficulty == .custom ? "Custom controls the number of empty cells, not the logical difficulty. Very sparse requests can take longer or need another attempt." :
                            "Collection puzzles use published difficulty ratings. Generated puzzles are graded by the deductions needed to solve them.")
                }
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(PlayMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    Label(mode == .challenge ? "Immediate feedback" : "Room to explore", systemImage: mode == .challenge ? "checkmark.shield" : "pencil.and.outline")
                        .font(.subheadline)
                } footer: {
                    Text(mode == .challenge ? "Wrong entries are rejected and count as strikes, even if they don't duplicate a number. \(model.preferences.strikeLimit == 0 ? "No strike limit." : "\(model.preferences.strikeLimit) strikes end the attempt.") Notes are never checked." :
                            "Entries stay on the board without automatic checking. Use Check Board in the game menu whenever you want feedback.")
                }
                Section {
                    Picker("Puzzle source", selection: $source) {
                        ForEach(PuzzleSource.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.disabled(difficulty == .custom)
                    .accessibilityIdentifier("source-picker")
                } footer: {
                    Text(difficulty == .custom ? "Custom puzzles are generated on your device." :
                            source == .collection ? "400 rated, uniqueness-checked puzzles. No downloads needed." :
                            "Fresh puzzles, generated and checked entirely offline. Expert puzzles may take a moment.")
                }
                if let error = model.generationError {
                    Section { Text(error).foregroundStyle(.red).font(.callout) }
                }
                Section {
                    Button {
                        Task {
                            if await model.start(difficulty: difficulty, mode: mode,
                                                 source: difficulty == .custom ? .generated : source, empty: Int(empty)) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if model.generating {
                                ProgressView().padding(.trailing, 6)
                                Text("Preparing your puzzle…")
                            } else { Text("Start Puzzle").fontWeight(.semibold) }
                            Spacer()
                        }.padding(.vertical, 8)
                    }
                    .disabled(model.generating)
                } footer: {
                    if model.game != nil { Text("Your current puzzle is replaced only when the new one is ready.") }
                }
            }
            .disabled(model.generating)
            .navigationTitle("New puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.generating ? "Cancel" : "Done") { model.cancelGeneration(); dismiss() }
                }
            }
        }
        .onAppear { model.generationError = nil }
        .onDisappear { model.cancelGeneration() }
    }
}
