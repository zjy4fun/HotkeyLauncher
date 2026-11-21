import Foundation

struct AppSettings: Codable, Equatable {
    var opensNewWindowWhenNoVisibleWindows: Bool
    var showsMenuBarIcon: Bool

    static let `default` = AppSettings(opensNewWindowWhenNoVisibleWindows: true)

    init(opensNewWindowWhenNoVisibleWindows: Bool, showsMenuBarIcon: Bool = true) {
        self.opensNewWindowWhenNoVisibleWindows = opensNewWindowWhenNoVisibleWindows
        self.showsMenuBarIcon = showsMenuBarIcon
    }

    private enum CodingKeys: String, CodingKey {
        case opensNewWindowWhenNoVisibleWindows
        case showsMenuBarIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        opensNewWindowWhenNoVisibleWindows = try container.decode(
            Bool.self, forKey: .opensNewWindowWhenNoVisibleWindows
        )
        showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon) ?? true
    }
}

struct ShortcutStorage {
    var shortcutsURL: URL
    var settingsURL: URL

    static let live = ShortcutStorage(
        shortcutsURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/HotkeyLauncher/shortcuts.json"),
        settingsURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/HotkeyLauncher/settings.json")
    )

    func load() -> [HotkeyShortcut] {
        guard
            let data = try? Data(contentsOf: shortcutsURL),
            let shortcuts = try? JSONDecoder().decode([HotkeyShortcut].self, from: data)
        else {
            return []
        }

        return shortcuts
    }

    func loadSettings() -> AppSettings {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    func save(_ shortcuts: [HotkeyShortcut]) throws {
        try createSupportDirectory()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(shortcuts)
        try data.write(to: shortcutsURL, options: .atomic)
    }

    func saveSettings(_ settings: AppSettings) throws {
        try createSupportDirectory()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    func exportConfiguration(shortcuts: [HotkeyShortcut], settings: AppSettings, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let configuration = ExportedConfiguration(settings: settings, shortcuts: shortcuts)
        let data = try encoder.encode(configuration)
        try data.write(to: url, options: .atomic)
    }

    func importConfiguration(from url: URL) throws -> ExportedConfiguration {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ExportedConfiguration.self, from: data)
        } catch {
            let shortcuts = try JSONDecoder().decode([HotkeyShortcut].self, from: data)
            return ExportedConfiguration(settings: .default, shortcuts: shortcuts)
        }
    }

    private func createSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: shortcutsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
