import SwiftUI

struct SettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var opensNewWindowWhenNoVisibleWindows: Bool
    @Binding var showsMenuBarIcon: Bool

    let latestUpdate: UpdateInfo?
    let isCheckingForUpdates: Bool
    let isDownloadingUpdate: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    let onCheckForUpdates: () -> Void
    let onDownloadUpdate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                settingsSection("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Show menu bar icon", isOn: $showsMenuBarIcon)
                            .toggleStyle(.switch)

                        Text("Global shortcuts keep working when the icon is hidden. To restore the icon, open HotkeyLauncher from Finder or Spotlight and turn this switch on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("New window when none are visible", isOn: $opensNewWindowWhenNoVisibleWindows)
                            .toggleStyle(.switch)

                        Text("Applies to all shortcuts. When the target app is already running with no visible windows, HotkeyLauncher activates it and sends Command+N.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !showsMenuBarIcon {
                        Button("Quit HotkeyLauncher") {
                            NSApp.terminate(nil)
                        }
                    }
                }

                settingsSection("Configuration") {
                    HStack(spacing: 10) {
                        Button {
                            onImport()
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            onExport()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Text("Import or export shortcuts and global settings as a JSON package.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                settingsSection("Updates") {
                    AboutUpdateView(
                        latestUpdate: latestUpdate,
                        isCheckingForUpdates: isCheckingForUpdates,
                        isDownloadingUpdate: isDownloadingUpdate,
                        onCheckForUpdates: onCheckForUpdates,
                        onDownloadUpdate: onDownloadUpdate
                    )
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Manage app-level behavior, configuration files, and updates.")
                .foregroundStyle(.secondary)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.separator, lineWidth: 1)
            }
        }
    }
}
