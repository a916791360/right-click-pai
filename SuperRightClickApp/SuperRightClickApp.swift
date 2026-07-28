import AppKit
import SwiftUI

@main
@MainActor
final class SuperRightClickApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settingsWindowController: NSWindowController?
    private var settingsLaunchWorkItem: DispatchWorkItem?
    private let moveRequestCoordinator = MoveRequestCoordinator()
    private var isHandlingMoveRequest = false

    static func main() {
        let application = NSApplication.shared
        let delegate = SuperRightClickApp()
        application.delegate = delegate
        application.run()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isHandlingMoveRequest else { return }
            self.showSettingsWindow()
        }
        settingsLaunchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !isHandlingMoveRequest else { return false }
        showSettingsWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindowController?.window else { return }
        settingsWindowController = nil
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: value),
            MoveRequestStore.identifier(from: url) != nil
        else {
            return
        }

        handleMoveRequest(url)
    }

    private func handleMoveRequest(_ url: URL) {
        guard !isHandlingMoveRequest else { return }
        isHandlingMoveRequest = true
        settingsLaunchWorkItem?.cancel()

        let shouldRestoreSettings = settingsWindowController?.window?.isVisible == true
        settingsWindowController?.window?.orderOut(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        moveRequestCoordinator.handle(url) { [weak self] in
            guard let self else { return }
            self.isHandlingMoveRequest = false
            if shouldRestoreSettings {
                self.showSettingsWindow()
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)

        if let windowController = settingsWindowController {
            windowController.showWindow(nil)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "右键派"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(hostingController.view.fittingSize)
        window.center()

        let windowController = NSWindowController(window: window)
        settingsWindowController = windowController
        windowController.showWindow(nil)
        NSApp.activate()
    }
}
