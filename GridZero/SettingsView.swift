import SwiftUI
import GridZeroCore

struct SettingsView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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
                } header: { Text("Make it yours") } footer: {
                    if model.preferences.appearance == .scheduled {
                        Text("Uses your local clock. No location access needed. Different light and dark times work best.")
                    } else { Text("System follows your iPhone. Scheduled is an optional daily light/dark switch.") }
                }
                Section {
                    Picker("Default puzzle source", selection: $model.preferences.source) {
                        ForEach(PuzzleSource.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Challenge strike limit", selection: $model.preferences.strikeLimit) {
                        Text("3 strikes").tag(3)
                        Text("5 strikes").tag(5)
                        Text("10 strikes").tag(10)
                        Text("Unlimited").tag(0)
                    }
                } header: { Text("New puzzles") } footer: {
                    Text("Strike limits apply to new games. Your current game's rules stay consistent.")
                }
                Section {
                    Toggle("Enable Fill Notes", isOn: $model.preferences.allowAutofill)
                    Toggle("Automatically clean up notes", isOn: $model.preferences.cleanupNotes)
                } header: { Text("Optional assistance") } footer: {
                    Text("Notes are manual by default. Fill Notes adds an undoable action to the game menu. Cleanup removes placed digits from related cells. Both use only the current board, never the hidden solution.")
                }
                Section("While you play") {
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
                    Text("Free, open source, and entirely offline. No ads. No tracking. No accounts.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link("Visit gridzero.win", destination: URL(string: "https://gridzero.win")!)
                    Link("Privacy & Support", destination: URL(string: "https://gridzero.win/support/")!)
                    Text("8,000 collection puzzles courtesy of Grant McLean / Sudoku Exchange, generated with QQWing and rated with Sukaku Explainer. Public domain. Easy / Medium / Hard / Expert correspond to its Easy / Medium / Hard / Diabolical ratings.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("Puzzle credits & licenses", destination: URL(string: "https://gridzero.win/credits/")!)
                } header: { Text("Zero distractions") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
