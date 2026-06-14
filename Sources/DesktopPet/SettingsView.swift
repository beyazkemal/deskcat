import SwiftUI

struct SettingsView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case general = "General"
        case focus = "Focus"
        case integrations = "Integrations"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "cat"
            case .focus: return "timer"
            case .integrations: return "link"
            }
        }
        var subtitle: String {
            switch self {
            case .general: return "Personalize your companion"
            case .focus: return "Build a calmer work rhythm"
            case .integrations: return "Let DeskCat react to your tools"
            }
        }
    }

    @ObservedObject var settings: AppSettings
    @ObservedObject var hooks: HookInstaller
    @ObservedObject var engine: PetEngine
    @State private var selection: Section = .general
    @State private var nameDraft: String

    init(settings: AppSettings, hooks: HookInstaller, engine: PetEngine) {
        self.settings = settings
        self.hooks = hooks
        self.engine = engine
        _nameDraft = State(initialValue: settings.catName)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(width: 660, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "cat.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DeskCat").font(.headline)
                    Text(settings.catName).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)

            VStack(spacing: 4) {
                ForEach(Section.allCases) { item in
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .frame(width: 18)
                            Text(item.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: selection == item ? .semibold : .regular))
                        .foregroundStyle(selection == item ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .contentShape(Rectangle())
                        .background(selection == item ? Color.accentColor.opacity(0.14) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }

            Spacer()
            Text("A quiet companion for your desktop.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
        }
        .padding(16)
        .frame(width: 180)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.rawValue)
                    .font(.system(size: 24, weight: .semibold))
                Text(selection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Group {
                switch selection {
                case .general: generalContent
                case .focus: focusContent
                case .integrations: integrationsContent
                }
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var generalContent: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Identity", subtitle: "Give your cat a name and a look.") {
                SettingRow(title: "Cat name") {
                    HStack(spacing: 8) {
                        TextField("Tekir", text: $nameDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 190)
                            .onSubmit { saveName() }
                        Button("Save") { saveName() }
                            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                SettingRow(title: "Fur color") {
                    Picker("", selection: $settings.skinName) {
                        Text("Orange tabby").tag("orange")
                        Text("Gray").tag("gray")
                        Text("Cream").tag("cream")
                        Text("Tuxedo").tag("tuxedo")
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: settings.skinName) { engine.setSkin($0) }
                }
            }

            SettingsCard(title: "Behavior", subtitle: "Choose when DeskCat rests and stretches.") {
                SettingRow(title: "Sleep after") {
                    HStack(spacing: 10) {
                        Slider(value: $settings.sleepSeconds, in: 6...60, step: 1)
                            .frame(width: 180)
                        ValueBadge(text: "\(Int(settings.sleepSeconds)) sec")
                    }
                }
                SettingRow(title: "Stretch reminder") {
                    Picker("", selection: $settings.reminderMinutes) {
                        Text("Off").tag(0)
                        Text("Every 20 min").tag(20)
                        Text("Every 30 min").tag(30)
                        Text("Every 60 min").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: settings.reminderMinutes) { engine.setReminder(minutes: $0) }
                }
            }
        }
    }

    private var focusContent: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Pomodoro", subtitle: "A simple focus and break loop.") {
                SettingRow(title: "Focus duration") {
                    Stepper("\(settings.focusMinutes) min", value: $settings.focusMinutes, in: 1...120)
                        .frame(width: 125)
                }
                SettingRow(title: "Break duration") {
                    Stepper("\(settings.breakMinutes) min", value: $settings.breakMinutes, in: 1...60)
                        .frame(width: 125)
                }
                SettingRow(title: "Auto-start next phase") {
                    Toggle("", isOn: $settings.autoStartNext)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            HStack(spacing: 10) {
                Button(engine.pomodoroMenuTitle) { engine.togglePomodoro() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Reset") { engine.resetPomodoro() }
                    .controlSize(.large)
            }
        }
    }

    private var integrationsContent: some View {
        VStack(spacing: 14) {
            ForEach(HookInstaller.Tool.allCases) { tool in
                HStack(spacing: 14) {
                    Image(systemName: tool == .codex ? "terminal.fill" : "sparkles")
                        .font(.system(size: 19))
                        .foregroundStyle(tool == .codex ? .blue : .orange)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tool.rawValue).font(.headline)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(hooks.installed.contains(tool) ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 7, height: 7)
                            Text(hooks.installed.contains(tool) ? "Connected" : "Not connected")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if hooks.installed.contains(tool) {
                        Button("Disconnect") { hooks.uninstall(tool) }
                    } else {
                        Button("Connect") { hooks.install(tool) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
            }

            if let error = hooks.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }

            Text("Codex may ask you to trust the new hooks from its /hooks screen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func saveName() {
        settings.updateCatName(nameDraft)
        nameDraft = settings.catName
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 12) { content }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 16) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            content
        }
        .frame(minHeight: 28)
    }
}

private struct ValueBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .frame(minWidth: 58)
    }
}
