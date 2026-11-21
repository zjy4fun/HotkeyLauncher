import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcuts: [HotkeyShortcut]
    @Published private(set) var statuses: [UUID: ShortcutStatus] = [:]
    @Published var selectedID: UUID?
    @Published var isShowingSettings = false
    @Published var launchAtLogin: Bool
    @Published var opensNewWindowWhenNoVisibleWindows: Bool
    @Published private(set) var showsMenuBarIcon: Bool
    @Published var alert: AlertItem?
    @Published var latestUpdate: UpdateInfo?
    @Published var isCheckingForUpdates = false
    @Published var isDownloadingUpdate = false

    private let storage: ShortcutStorage
    private var hotKeyCenter: GlobalHotKeyCenter?
    private var registrationsSuspended = false
    private var didStart = false

    init(storage: ShortcutStorage = .live) {
        self.storage = storage

        let savedShortcuts = storage.load()
        let initialShortcuts = savedShortcuts.isEmpty ? HotkeyShortcut.defaultShortcuts() : savedShortcuts

        self.shortcuts = initialShortcuts
        self.selectedID = initialShortcuts.first?.id
        self.launchAtLogin = LoginItemInstaller.isEnabled(bundleURL: Bundle.main.bundleURL)
        let settings = storage.loadSettings()
        self.opensNewWindowWhenNoVisibleWindows = settings.opensNewWindowWhenNoVisibleWindows
        self.showsMenuBarIcon = settings.showsMenuBarIcon
    }

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        AppLog.write("store start")
        self.hotKeyCenter = GlobalHotKeyCenter { [weak self] shortcutID in
            Task { @MainActor in
                self?.openShortcut(id: shortcutID)
            }
        }

        persist()
        refreshRegistrations()
    }

    var selectedShortcut: HotkeyShortcut? {
        guard !isShowingSettings else {
            return nil
        }

        guard let selectedID else {
            return nil
        }
        return shortcuts.first(where: { $0.id == selectedID })
    }

    func selectShortcut(id: UUID) {
        selectedID = id
        isShowingSettings = false
    }

    func showSettings() {
        isShowingSettings = true
    }

    func shortcut(id: UUID) -> HotkeyShortcut? {
        shortcuts.first(where: { $0.id == id })
    }

    func status(for shortcutID: UUID) -> ShortcutStatus {
        statuses[shortcutID] ?? .disabled
    }

    func updateShortcut(_ shortcut: HotkeyShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else {
            return
        }

        shortcuts[index] = shortcut
        persist()
        refreshRegistrations()
    }

    func removeSelectedShortcut() {
        guard let selectedID else {
            return
        }

        shortcuts.removeAll { $0.id == selectedID }
        self.selectedID = shortcuts.first?.id
        persist()
        refreshRegistrations()
    }

    func addApplicationFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        addApplication(url)
    }

    func chooseApplication(for shortcutID: UUID) {
        guard var shortcut = shortcut(id: shortcutID) else {
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let metadata = AppResolver.metadata(for: url)
        shortcut.name = metadata.name
        shortcut.appPath = url.path
        shortcut.bundleIdentifier = metadata.bundleIdentifier
        updateShortcut(shortcut)
    }

    func addApplication(_ url: URL) {
        let metadata = AppResolver.metadata(for: url)
        let shortcut = HotkeyShortcut(
            name: metadata.name,
            appPath: url.path,
            bundleIdentifier: metadata.bundleIdentifier,
            hotkey: .optionCommand(kVK_ANSI_A),
            isEnabled: false
        )

        shortcuts.append(shortcut)
        selectedID = shortcut.id
        isShowingSettings = false
        persist()
        refreshRegistrations()
    }

    func openSelectedShortcut() {
        guard let selectedID else {
            return
        }
        openShortcut(id: selectedID)
    }

    func openShortcut(id: UUID) {
        guard let shortcut = shortcut(id: id) else {
            return
        }

        AppLog.write("open \(shortcut.name)")
        ApplicationLauncher.open(
            shortcut,
            opensNewWindowWhenNoVisibleWindows: opensNewWindowWhenNoVisibleWindows
        ) { [weak self] errorMessage in
            guard let errorMessage else {
                return
            }

            Task { @MainActor in
                self?.alert = AlertItem(
                    title: "Open Failed",
                    message: errorMessage
                )
            }
        }
    }

    func setOpensNewWindowWhenNoVisibleWindows(_ enabled: Bool) {
        opensNewWindowWhenNoVisibleWindows = enabled
        persistSettings()
    }

    func setShowsMenuBarIcon(_ enabled: Bool) {
        showsMenuBarIcon = enabled
        persistSettings()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemInstaller.setEnabled(enabled, bundleURL: Bundle.main.bundleURL)
            launchAtLogin = enabled
        } catch {
            alert = AlertItem(title: "Login Item Failed", message: error.localizedDescription)
            launchAtLogin = LoginItemInstaller.isEnabled(bundleURL: Bundle.main.bundleURL)
        }
    }

    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "HotkeyLauncher-Config.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try storage.exportConfiguration(
                shortcuts: shortcuts,
                settings: currentSettings,
                to: url
            )
            alert = AlertItem(title: "Export Complete", message: "Configuration exported to \(url.path).")
        } catch {
            alert = AlertItem(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let configuration = try storage.importConfiguration(from: url)
            shortcuts = configuration.shortcuts
            opensNewWindowWhenNoVisibleWindows = configuration.settings.opensNewWindowWhenNoVisibleWindows
            showsMenuBarIcon = configuration.settings.showsMenuBarIcon
            selectedID = shortcuts.first?.id
            persist()
            persistSettings()
            refreshRegistrations()
            alert = AlertItem(title: "Import Complete", message: "Imported \(shortcuts.count) shortcuts.")
        } catch {
            alert = AlertItem(title: "Import Failed", message: error.localizedDescription)
        }
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else {
            return
        }

        isCheckingForUpdates = true

        Task {
            do {
                let update = try await UpdateChecker.latestUpdate()
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.latestUpdate = update

                    if AppVersion.compare(AppVersion.current, update.displayVersion) == .orderedAscending {
                        self.alert = AlertItem(
                            title: "Update Available",
                            message: "Version \(update.displayVersion) is available. Use Download Update to open the GitHub release."
                        )
                    } else {
                        self.alert = AlertItem(
                            title: "Up to Date",
                            message: "HotkeyLauncher \(AppVersion.current) is the latest version."
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.alert = AlertItem(title: "Update Check Failed", message: error.localizedDescription)
                }
            }
        }
    }

    func downloadLatestUpdate() {
        guard let latestUpdate else {
            checkForUpdates()
            return
        }

        guard !isDownloadingUpdate else {
            return
        }

        isDownloadingUpdate = true

        Task {
            do {
                try await UpdateChecker.downloadAndOpen(latestUpdate)
                await MainActor.run {
                    self.isDownloadingUpdate = false
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingUpdate = false
                    UpdateChecker.openRelease(latestUpdate)
                    self.alert = AlertItem(
                        title: "Download Failed",
                        message: "Opened the GitHub release page instead. \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func setRecordingActive(_ active: Bool) {
        registrationsSuspended = active
        if active {
            hotKeyCenter?.unregisterAll()
        } else {
            refreshRegistrations()
        }
    }

    func refreshRegistrations() {
        guard !registrationsSuspended else {
            return
        }

        var nextStatuses: [UUID: ShortcutStatus] = [:]
        var candidates: [HotkeyShortcut] = []

        for shortcut in shortcuts {
            if !shortcut.isEnabled {
                nextStatuses[shortcut.id] = .disabled
            } else if !AppResolver.applicationExists(at: shortcut.appPath) {
                nextStatuses[shortcut.id] = .missingApplication
            } else {
                candidates.append(shortcut)
            }
        }

        let groupedByHotkey = Dictionary(grouping: candidates, by: { $0.hotkey })
        let duplicateIDs = Set(
            groupedByHotkey
                .filter { $0.value.count > 1 }
                .flatMap { $0.value.map(\.id) }
        )

        for duplicateID in duplicateIDs {
            nextStatuses[duplicateID] = .duplicate
        }

        let registerable = candidates.filter { !duplicateIDs.contains($0.id) }
        guard let hotKeyCenter else {
            for shortcut in registerable {
                nextStatuses[shortcut.id] = .disabled
            }
            statuses = nextStatuses
            return
        }

        let registrationStatuses = hotKeyCenter.register(shortcuts: registerable)

        for shortcut in registerable {
            nextStatuses[shortcut.id] = registrationStatuses[shortcut.id] ?? .error(-1)
        }

        statuses = nextStatuses
    }

    private func persist() {
        do {
            try storage.save(shortcuts)
        } catch {
            alert = AlertItem(title: "Save Failed", message: error.localizedDescription)
        }
    }

    private func persistSettings() {
        do {
            try storage.saveSettings(currentSettings)
        } catch {
            alert = AlertItem(title: "Save Failed", message: error.localizedDescription)
        }
    }

    private var currentSettings: AppSettings {
        AppSettings(
            opensNewWindowWhenNoVisibleWindows: opensNewWindowWhenNoVisibleWindows,
            showsMenuBarIcon: showsMenuBarIcon
        )
    }
}
