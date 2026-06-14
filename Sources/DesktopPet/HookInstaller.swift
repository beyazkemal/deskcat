import Foundation

final class HookInstaller: ObservableObject {
    enum Tool: String, CaseIterable, Identifiable {
        case codex = "Codex"
        case claude = "Claude Code"
        var id: String { rawValue }
    }

    @Published private(set) var installed: Set<Tool> = []
    @Published var lastError: String?

    init() { refresh() }

    func refresh() {
        installed = Set(Tool.allCases.filter { containsDeskCatHook(in: settingsURL(for: $0)) })
    }

    func install(_ tool: Tool) {
        do {
            let url = settingsURL(for: tool)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            var root = try loadJSON(url)
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            hooks["UserPromptSubmit"] = appendHook(to: hooks["UserPromptSubmit"], source: tool, event: "start")
            hooks["Stop"] = appendHook(to: hooks["Stop"], source: tool, event: "done")
            if tool == .claude {
                hooks["StopFailure"] = appendHook(to: hooks["StopFailure"], source: tool, event: "failed")
            }
            root["hooks"] = hooks
            try backup(url)
            try writeJSON(root, to: url)
            lastError = nil
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func uninstall(_ tool: Tool) {
        do {
            let url = settingsURL(for: tool)
            var root = try loadJSON(url)
            guard var hooks = root["hooks"] as? [String: Any] else { return }
            for event in ["UserPromptSubmit", "Stop", "StopFailure"] {
                hooks[event] = removeDeskCatHooks(from: hooks[event])
            }
            root["hooks"] = hooks
            try backup(url)
            try writeJSON(root, to: url)
            lastError = nil
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func settingsURL(for tool: Tool) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch tool {
        case .codex: return home.appendingPathComponent(".codex/hooks.json")
        case .claude: return home.appendingPathComponent(".claude/settings.json")
        }
    }

    private func command(source: Tool, event: String) -> String {
        let helper = Bundle.main.resourceURL?.appendingPathComponent("deskcat-agent-event.sh").path
            ?? Bundle.main.bundlePath + "/Contents/Resources/deskcat-agent-event.sh"
        return "\"\(helper)\" --source \(source == .codex ? "codex" : "claude") --event \(event)"
    }

    private func appendHook(to value: Any?, source: Tool, event: String) -> [[String: Any]] {
        var groups = value as? [[String: Any]] ?? []
        let newCommand = command(source: source, event: event)
        let exists = groups.contains { group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return handlers.contains { ($0["command"] as? String)?.contains("deskcat-agent-event.sh") == true }
        }
        if !exists {
            groups.append(["hooks": [["type": "command", "command": newCommand, "timeout": 5]]])
        }
        return groups
    }

    private func removeDeskCatHooks(from value: Any?) -> [[String: Any]] {
        let groups = value as? [[String: Any]] ?? []
        return groups.compactMap { group in
            var copy = group
            let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter {
                ($0["command"] as? String)?.contains("deskcat-agent-event.sh") != true
            }
            guard !handlers.isEmpty else { return nil }
            copy["hooks"] = handlers
            return copy
        }
    }

    private func containsDeskCatHook(in url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains("deskcat-agent-event.sh")
    }

    private func loadJSON(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func backup(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.appendingPathExtension("deskcat-backup")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.copyItem(at: url, to: backup)
    }
}
