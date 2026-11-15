import SwiftUI
import GridZeroCore

struct SettingsView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var strikeText = ""
    @FocusState private var strikeFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ForEach(Theme.allCases) { theme in
                            Button { model.preferences.theme = theme } label: {
                                VStack(spacing: 10) {
                                    Circle().fill(theme.accent(dark: colorScheme == .dark)).frame(width: 30, height: 30)
                                        .overlay {
                                            if model.preferences.theme == theme {
                                                Image(systemName: "checkmark").font(.caption.bold())
                                                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                                            }
                                        }
                                    Text(theme.title).font(.subheadline)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(model.preferences.theme == theme ? theme.accent(dark: colorScheme == .dark).opacity(0.1) : .clear,
                                            in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(theme.title) theme")
                            .accessibilityAddTraits(model.preferences.theme == theme ? .isSelected : [])
                        }
                    }
                    Picker("Appearance", selection: $model.preferences.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("appearance-picker")
                    if model.preferences.appearance == .scheduled {
                        DatePicker("Light at", selection: timeBinding(light: true), displayedComponents: .hourAndMinute)
                        DatePicker("Dark at", selection: timeBinding(light: false), displayedComponents: .hourAndMinute)
                    }
                } header: { Text("Appearance") }
                Section {
                    Picker("Default puzzle source", selection: $model.preferences.source) {
                        ForEach(PuzzleSource.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Stepper(value: $model.preferences.strikeLimit, in: 1...5) {
                        HStack {
                            Text("Challenge strike limit")
                            Spacer()
                            TextField("Strike limit", text: $strikeText)
                            .keyboardType(.numberPad)
                            .focused($strikeFocused)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .frame(width: 36)
                            .accessibilityLabel("Challenge strike limit")
                        }
                    }
                } header: { Text("New puzzles") }
                Section {
                    Toggle("Enable Fill Notes", isOn: $model.preferences.allowAutofill)
                    Toggle("Automatically clean up notes", isOn: $model.preferences.cleanupNotes)
                } header: { Text("Notes") }
                Section("Gameplay") {
                    Toggle("Highlight related cells", isOn: $model.preferences.highlightPeers)
                    Toggle("Highlight matching numbers", isOn: $model.preferences.highlightMatching)
                    Toggle("Show timer", isOn: $model.preferences.showTimer)
                    Toggle("Gentle haptics", isOn: $model.preferences.haptics)
                }
                Section {
                    HStack {
                        Text("GridZero")
                        Spacer()
                        Text("1.0").foregroundStyle(.secondary)
                    }
                    Link("Visit gridzero.win", destination: URL(string: "https://gridzero.win")!)
                    Link("Privacy & Support", destination: URL(string: "https://gridzero.win/support/")!)
                    Link("Puzzle credits & licenses", destination: URL(string: "https://gridzero.win/credits/")!)
                } header: { Text("About") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { strikeText = String(model.preferences.strikeLimit) }
            .onChange(of: strikeText) { _, text in
                guard let value = Int(text) else { return }
                let bounded = min(5, max(1, value))
                model.preferences.strikeLimit = bounded
                if value != bounded { strikeText = String(bounded) }
            }
            .onChange(of: model.preferences.strikeLimit) { _, value in strikeText = String(value) }
            .onChange(of: strikeFocused) { _, focused in
                if !focused { strikeText = String(model.preferences.strikeLimit) }
            }
        }
    }
    private func timeBinding(light: Bool) -> Binding<Date> {
        Binding {
            let minutes = light ? model.preferences.lightAt : model.preferences.darkAt
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                         second: 0, of: Date()) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            if light { model.preferences.lightAt = minutes } else { model.preferences.darkAt = minutes }
            model.clock = Date()
        }
    }
}
