import Foundation

final class AppSettings: ObservableObject {
    private enum Key {
        static let catName = "catName"
        static let skinName = "skinName"
        static let sleepSeconds = "sleepSeconds"
        static let reminderMinutes = "reminderMinutes"
        static let focusMinutes = "focusMinutes"
        static let breakMinutes = "breakMinutes"
        static let autoStartNext = "autoStartNext"
    }

    private let defaults: UserDefaults

    @Published var catName: String { didSet { defaults.set(catName, forKey: Key.catName) } }
    @Published var skinName: String { didSet { defaults.set(skinName, forKey: Key.skinName) } }
    @Published var sleepSeconds: Double { didSet { defaults.set(sleepSeconds, forKey: Key.sleepSeconds) } }
    @Published var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: Key.reminderMinutes) } }
    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    @Published var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: Key.breakMinutes) } }
    @Published var autoStartNext: Bool { didSet { defaults.set(autoStartNext, forKey: Key.autoStartNext) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        catName = defaults.string(forKey: Key.catName) ?? "Tekir"
        skinName = defaults.string(forKey: Key.skinName) ?? "orange"
        sleepSeconds = defaults.object(forKey: Key.sleepSeconds) as? Double ?? 6
        reminderMinutes = defaults.object(forKey: Key.reminderMinutes) as? Int ?? 0
        focusMinutes = defaults.object(forKey: Key.focusMinutes) as? Int ?? 25
        breakMinutes = defaults.object(forKey: Key.breakMinutes) as? Int ?? 5
        autoStartNext = defaults.bool(forKey: Key.autoStartNext)
    }

    func updateCatName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { catName = String(trimmed.prefix(30)) }
    }
}
