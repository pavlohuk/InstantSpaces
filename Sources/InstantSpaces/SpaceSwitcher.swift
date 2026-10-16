import CShims
import Foundation

enum SpaceStep {
    case next
    case previous
}

/// Asks the Dock to switch one space instantly (synthetic swipe with a huge fling velocity).
///
/// The Dock itself performs the switch, so windows of the previous space are hidden properly and
/// full-screen app spaces work like any other space.
final class SpaceSwitcher {
    /// While our own swipes are still landing, SkyLight reports an intermediate space. Trusting it
    /// during a burst of swipes would let us overshoot past the last space, which on macOS 27 can
    /// wedge the Dock (black screen). Keep our own prediction authoritative for this long.
    private let predictionTTL: TimeInterval = 1.0
    private var predicted: (display: String, index: UInt32, at: Date)?

    @discardableResult
    func perform(_ step: SpaceStep) -> Bool {
        var info = ISSpaceInfo()
        guard is_spaces_info(&info) else {
            log.error("could not read spaces of the current display")
            return false
        }
        let display = withUnsafeBytes(of: info.display) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }

        var current = info.index
        if let p = predicted, p.display == display, Date().timeIntervalSince(p.at) < predictionTTL {
            current = p.index
        }

        let target: UInt32
        switch step {
        case .next:
            guard current + 1 < info.count else {
                log.debug("already on the last space")
                return false
            }
            target = current + 1
        case .previous:
            guard current > 0 else {
                log.debug("already on the first space")
                return false
            }
            target = current - 1
        }

        guard is_ds_post_switch(step == .next ? 1 : -1) else {
            log.error("could not post the synthetic swipe")
            return false
        }
        predicted = (display, target, Date())
        log.notice("switch \(step == .next ? "next" : "previous", privacy: .public): space \(current + 1) -> \(target + 1) of \(info.count)")
        return true
    }
}
