import Cocoa

/// Fires `onHold` when exactly the hyper modifiers have been held, with no other key, for `holdTime`.
final class HotkeyWatcher {
    var hyper: CGEventFlags = [.maskAlternate, .maskCommand]
    static let relevant: CGEventFlags = [.maskAlternate, .maskCommand, .maskShift, .maskControl]

    let holdTime: TimeInterval
    var onHold: () -> Void = {}
    var onCancel: () -> Void = {}
    var beforeEvent: () -> Void = {}

    private var tap: CFMachPort?
    private var timer: DispatchSourceTimer?

    func setHyper(_ mods: Set<String>) {
        var f: CGEventFlags = []
        if mods.contains("alt") { f.insert(.maskAlternate) }
        if mods.contains("cmd") { f.insert(.maskCommand) }
        if mods.contains("shift") { f.insert(.maskShift) }
        if mods.contains("ctrl") { f.insert(.maskControl) }
        hyper = f
    }

    init(holdTime: TimeInterval) { self.holdTime = holdTime }

    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let watcher = Unmanaged<HotkeyWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            watcher.handle(type, event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .listenOnly, eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            beforeEvent()
            if event.flags.intersection(Self.relevant) == hyper {
                if timer == nil { arm() }
            } else {
                cancel()
            }
        case .keyDown:
            cancel()
        default: break
        }
    }

    private func arm() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + holdTime)
        t.setEventHandler { [weak self] in
            self?.timer?.cancel(); self?.timer = nil
            self?.onHold()
        }
        timer = t
        t.resume()
    }

    private func cancel() {
        timer?.cancel(); timer = nil
        onCancel()
    }
}
