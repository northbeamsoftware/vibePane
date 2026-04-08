import SwiftUI
import AppKit
import ServiceManagement

@main
struct VibePaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = DataStore()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupGlobalHotkey()
        enableLaunchAtLogin()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.2", accessibilityDescription: "vibePane")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 580)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ProjectListView(store: store)
        )
    }

    private func setupGlobalHotkey() {
        // Ctrl+Option+D — avoids VS Code Cmd+Shift+D conflict
        let modifiers: NSEvent.ModifierFlags = [.control, .option]
        let keyCode: UInt16 = 2 // 'd'

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(modifiers) && event.keyCode == keyCode {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(modifiers) && event.keyCode == keyCode {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
                return nil
            }
            return event
        }
    }

    private func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
