import CShims
import Foundation

enum SpaceStep {
    case next
    case previous
}

/// Asks the Dock to switch spaces instantly (synthetic swipes with a huge fling velocity).
///
/// The Dock itself performs the switch, so windows of the previous space are hidden properly and
/// full-screen app spaces work like any other space.
final class SpaceSwitcher {
    /// While our own swipes are still landing, SkyLight reports an intermediate space. Trusting it
    /// during a burst would let us overshoot past the last space, which on macOS 27 can wedge the
    /// Dock (black screen). Keep our own prediction authoritative for this long.
    private let predictionTTL: TimeInterval = 1.0
    private var predicted: (display: String, index: Int, at: Date)?

    private struct State {
        let display: String
        let current: Int
        let types: [Int32]
        var count: Int { types.count }
        /// Indexes of ordinary desktops (not full-screen apps), in Dock order.
        var desktops: [Int] { types.indices.filter { types[$0] == 0 } }
    }

    /// One space to the right or left.
    @discardableResult
    func perform(_ step: SpaceStep) -> Bool {
        guard let state = readState() else { return false }
        let target = state.current + (step == .next ? 1 : -1)
        guard target >= 0, target < state.count else {
            log.debug("already on the \(step == .next ? "last" : "first", privacy: .public) space")
            return false
        }
        return move(state, to: target, reason: step == .next ? "next" : "previous")
    }

    /// True when desktop `number` (1-based, counting ordinary desktops only) exists.
    func hasDesktop(_ number: Int) -> Bool {
        guard let state = readState() else { return false }
        return number >= 1 && number <= state.desktops.count
    }

    /// Jumps straight to desktop `number` (1-based, counting ordinary desktops only, like the
    /// "Desktop N" labels in Mission Control). Returns false when there is no such desktop.
    @discardableResult
    func jump(toDesktop number: Int) -> Bool {
        guard let state = readState() else { return false }
        let desktops = state.desktops
        guard number >= 1, number <= desktops.count else {
            log.debug("no desktop \(number), only \(desktops.count)")
            return false
        }
        let target = desktops[number - 1]
        if target == state.current { return true }
        return move(state, to: target, reason: "desktop \(number)")
    }

    // MARK: Private

    private func move(_ state: State, to target: Int, reason: String) -> Bool {
        let direction: Int32 = target > state.current ? 1 : -1
        let steps = abs(target - state.current)
        for _ in 0..<steps {
            guard is_ds_post_switch(direction) else {
                log.error("could not post the synthetic swipe")
                return false
            }
        }
        predicted = (state.display, target, Date())
        log.notice("switch \(reason, privacy: .public): space \(state.current + 1) -> \(target + 1) of \(state.count)")
        return true
    }

    private func readState() -> State? {
        var info = ISSpaceInfo()
        guard is_spaces_info(&info), info.count > 0 else {
            log.error("could not read spaces of the current display")
            return nil
        }
        let display = withUnsafeBytes(of: info.display) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let count = Int(info.count)
        let types = withUnsafeBytes(of: info.types) { raw in
            Array(raw.bindMemory(to: Int32.self).prefix(count))
        }
        var current = Int(info.index)
        if let p = predicted, p.display == display, Date().timeIntervalSince(p.at) < predictionTTL, p.index < count {
            current = p.index
        }
        return State(display: display, current: current, types: types)
    }
}
