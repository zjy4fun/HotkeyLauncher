import Combine
import XCTest
@testable import HotkeyLauncher

final class AppSettingsTests: XCTestCase {
    func testExistingSettingsKeepWindowPreferenceAndShowIconByDefault() throws {
        let data = Data(#"{"opensNewWindowWhenNoVisibleWindows":false}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(settings.opensNewWindowWhenNoVisibleWindows)
        XCTAssertTrue(settings.showsMenuBarIcon)
    }

    func testHiddenIconSurvivesSaveAndReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = makeStorage(in: directory)
        let settings = AppSettings(opensNewWindowWhenNoVisibleWindows: false, showsMenuBarIcon: false)

        try storage.saveSettings(settings)

        XCTAssertEqual(storage.loadSettings(), settings)
    }

    func testConfigurationExportAndImportPreserveHiddenIcon() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storage = makeStorage(in: directory)
        let settings = AppSettings(opensNewWindowWhenNoVisibleWindows: false, showsMenuBarIcon: false)
        let url = directory.appendingPathComponent("configuration.json")

        try storage.exportConfiguration(shortcuts: [], settings: settings, to: url)
        let imported = try storage.importConfiguration(from: url)

        XCTAssertEqual(imported.settings, settings)
    }

    func testOlderConfigurationImportsWithoutResettingWindowPreference() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storage = makeStorage(in: directory)
        let url = directory.appendingPathComponent("old-configuration.json")
        try Data(#"{"version":1,"exportedAt":"2026-11-21T00:00:00Z","settings":{"opensNewWindowWhenNoVisibleWindows":false},"shortcuts":[]}"#.utf8).write(to: url)

        let imported = try storage.importConfiguration(from: url)

        XCTAssertFalse(imported.settings.opensNewWindowWhenNoVisibleWindows)
        XCTAssertTrue(imported.settings.showsMenuBarIcon)
    }

    func testLegacyShortcutArrayStillImportsWithVisibleIcon() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storage = makeStorage(in: directory)
        let url = directory.appendingPathComponent("shortcuts.json")
        try Data("[]".utf8).write(to: url)

        XCTAssertTrue(try storage.importConfiguration(from: url).settings.showsMenuBarIcon)
    }

    func testStorePublishesIconChangesAndRestoresSavedChoice() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let storage = makeStorage(in: directory)
            try storage.saveSettings(AppSettings(opensNewWindowWhenNoVisibleWindows: false))
            let store = ShortcutStore(storage: storage)
            var visibility: [Bool] = []
            let observation = store.$showsMenuBarIcon.sink { visibility.append($0) }
            defer { observation.cancel() }

            store.setShowsMenuBarIcon(false)
            XCTAssertEqual(visibility, [true, false])
            XCTAssertFalse(ShortcutStore(storage: storage).showsMenuBarIcon)
            XCTAssertFalse(storage.loadSettings().opensNewWindowWhenNoVisibleWindows)

            store.setShowsMenuBarIcon(true)
            XCTAssertEqual(visibility, [true, false, true])
            XCTAssertTrue(ShortcutStore(storage: storage).showsMenuBarIcon)
        }
    }

    private func makeStorage(in directory: URL) -> ShortcutStorage {
        ShortcutStorage(
            shortcutsURL: directory.appendingPathComponent("shortcuts.json"),
            settingsURL: directory.appendingPathComponent("settings.json")
        )
    }
}
