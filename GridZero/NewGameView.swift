import SwiftUI
import GridZeroCore

struct NewGameView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty: Difficulty
    @State private var mode: PlayMode
    @State private var source: PuzzleSource
    @State private var empty: Double
    @State private var showModeInfo = false

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
                    }
                }
                Section {
                    HStack {
                        Picker("Mode", selection: $mode) {
                            ForEach(PlayMode.allCases, id: \.self) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        Button { showModeInfo = true } label: {
                            Image(systemName: "info.circle").frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("About game mode")
                    }
                }
                Section {
                    Picker("Puzzle source", selection: $source) {
                        ForEach(PuzzleSource.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.disabled(difficulty == .custom)
                    .accessibilityIdentifier("source-picker")
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
                                 Text("Preparing…")
                            } else { Text("Start Puzzle").fontWeight(.semibold) }
                            Spacer()
                        }.padding(.vertical, 8)
                    }
                    .disabled(model.generating)
                }
            }
            .disabled(model.generating)
            .navigationTitle("New puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .alert(mode.title, isPresented: $showModeInfo) {
                Button("Done", role: .cancel) {}
            } message: {
                Text(mode == .challenge ?
                     "Wrong entries are rejected and add a strike. \(model.preferences.strikeLimit == 0 ? "No strike limit." : "\(model.preferences.strikeLimit) strikes end the attempt.") Undo does not remove strikes. Notes are not checked." :
                     "Enter numbers without automatic checking or strikes. Use Check Board in the game menu to check your entries.")
            }
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
