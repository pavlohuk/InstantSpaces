import AppKit
import ApplicationServices
import CShims

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Reachable from the C swipe handler, which cannot capture context.
    private static weak var current: AppDelegate?

    private var statusBar: StatusBarController?
    private let switcher = SpaceSwitcher()
    private var signalSources: [DispatchSourceSignal] = []
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.notice("InstantSpaces launched, pid \(ProcessInfo.processInfo.processIdentifier)")
        AppDelegate.current = self

        guard is_spaces_available() else {
            fail("Приватний API SkyLight для читання Spaces недоступний на цій версії macOS.")
            return
        }

        is_ds_set_swipe_handler { direction in
            AppDelegate.current?.handleNativeSwipe(direction: Int(direction))
        }
        is_ds_set_key_handler { keycode, flags, isRepeat in
            AppDelegate.current?.handleKey(keycode: keycode, flags: flags, isRepeat: isRepeat) ?? false
        }
        is_ds_set_intercept(Settings.shared.enabled)

        let statusBar = StatusBarController()
        statusBar.onSettingsChanged = { is_ds_set_intercept(Settings.shared.enabled) }
        statusBar.onTestSwitch = { [weak self] step in self?.switcher.perform(step) }
        statusBar.isAccessibilityGranted = { AXIsProcessTrusted() }
        statusBar.isInterceptActive = { is_ds_tap_installed() }
        self.statusBar = statusBar

        installSignalHandlers()
        startInterception()
    }

    // MARK: Interception

    /// Installs the event tap once Accessibility is granted; until then, asks once and polls.
    private func startInterception() {
        if AXIsProcessTrusted() {
            installTap()
            return
        }
        log.notice("Accessibility permission missing, asking")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.permissionTimer = nil
            log.notice("Accessibility permission granted")
            self?.installTap()
        }
    }

    private func installTap() {
        if is_ds_tap_install() {
            log.notice("swipe interception active")
        } else {
            log.error("could not create the event tap")
        }
        statusBar?.updateIcon()
    }

    /// Native swipe intercepted: +1 means the user swiped towards the next space.
    private func handleNativeSwipe(direction: Int) {
        var step: SpaceStep = direction > 0 ? .next : .previous
        if Settings.shared.invertDirection { step = step == .next ? .previous : .next }
        switcher.perform(step)
    }

    /// modifier+←/→ and modifier+1…9. Returns true when the key was ours and must be swallowed.
    private func handleKey(keycode: Int32, flags: UInt64, isRepeat: Bool) -> Bool {
        let settings = Settings.shared
        guard settings.enabled, Hotkeys.modifiersMatch(flags, settings.hotkeyModifier) else { return false }

        if settings.hotkeyArrows, keycode == Hotkeys.leftArrow || keycode == Hotkeys.rightArrow {
            // Auto-repeat would fire a burst of switches; swallow it without acting.
            if !isRepeat { switcher.perform(keycode == Hotkeys.rightArrow ? .next : .previous) }
            return true
        }

        if settings.hotkeyDigits, let number = Hotkeys.digits[keycode] {
            // No such desktop: let the key through so the app's own shortcut still works.
            if isRepeat { return switcher.hasDesktop(number) }
            return switcher.jump(toDesktop: number)
        }
        return false
    }

    // MARK: Misc

    /// `kill -USR1 <pid>` switches to the next space, `kill -USR2` to the previous one (handy for testing from a shell).
    private func installSignalHandlers() {
        let mapping: [(Int32, SpaceStep)] = [(SIGUSR1, .next), (SIGUSR2, .previous)]
        for (sig, step) in mapping {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.switcher.perform(step) }
            source.resume()
            signalSources.append(source)
        }
    }

    private func fail(_ message: String) {
        log.error("\(message, privacy: .public)")
        let alert = NSAlert()
        alert.messageText = "InstantSpaces не може працювати"
        alert.informativeText = message
        alert.runModal()
        NSApp.terminate(nil)
    }
}
