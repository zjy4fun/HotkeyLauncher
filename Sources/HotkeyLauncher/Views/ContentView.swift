import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ShortcutStore

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .environmentObject(store)
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(.regularMaterial)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, minHeight: 540)
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            store.start()
        }
    }

    @ViewBuilder
    private var detail: some View {
        if store.isShowingSettings {
            SettingsView(
                launchAtLogin: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ),
                opensNewWindowWhenNoVisibleWindows: Binding(
                    get: { store.opensNewWindowWhenNoVisibleWindows },
                    set: { store.setOpensNewWindowWhenNoVisibleWindows($0) }
                ),
                showsMenuBarIcon: Binding(
                    get: { store.showsMenuBarIcon },
                    set: { store.setShowsMenuBarIcon($0) }
                ),
                latestUpdate: store.latestUpdate,
                isCheckingForUpdates: store.isCheckingForUpdates,
                isDownloadingUpdate: store.isDownloadingUpdate,
                onImport: {
                    store.importConfiguration()
                },
                onExport: {
                    store.exportConfiguration()
                },
                onCheckForUpdates: {
                    store.checkForUpdates()
                },
                onDownloadUpdate: {
                    store.downloadLatestUpdate()
                }
            )
        } else if let shortcut = store.selectedShortcut {
            ShortcutDetailView(
                shortcut: binding(for: shortcut),
                status: store.status(for: shortcut.id),
                onChooseApplication: {
                    store.chooseApplication(for: shortcut.id)
                },
                onOpen: {
                    store.openShortcut(id: shortcut.id)
                },
                onRecordingChanged: { active in
                    store.setRecordingActive(active)
                }
            )
            .id(shortcut.id)
        } else {
            EmptyStateView {
                store.addApplicationFromPanel()
            }
        }
    }

    private func binding(for shortcut: HotkeyShortcut) -> Binding<HotkeyShortcut> {
        Binding(
            get: {
                store.shortcut(id: shortcut.id) ?? shortcut
            },
            set: { updatedShortcut in
                store.updateShortcut(updatedShortcut)
            }
        )
    }
}
