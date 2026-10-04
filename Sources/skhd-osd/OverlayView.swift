import Cocoa

final class OverlayView: NSView {
    static let unit: CGFloat = 64
    static let gap: CGFloat = 5
    static let pad: CGFloat = 28

    let hyper: [Int: Binding]
    let others: [Binding]

    let hyperMods: Set<String>

    init(bindings: [Binding], hyperMods: Set<String>) {
        self.hyperMods = hyperMods
        var h: [Int: Binding] = [:]
        var o: [Binding] = []
        for b in bindings {
            if b.mods == hyperMods, let c = b.keyCode { h[c] = b } else { o.append(b) }
        }
        hyper = h; others = o
        let u = Self.unit
        let kbW = 14.5 * u + Self.pad * 2
        let otherRows = CGFloat((o.count + 1) / 2)
        let kbH = 5 * u + Self.pad * 2
        super.init(frame: NSRect(x: 0, y: 0, width: kbW, height: kbH + 56 + (o.isEmpty ? 0 : otherRows * 20 + 24)))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let u = Self.unit, g = Self.gap
        let sym = ["ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘", "fn": "fn"]
        let title = (["ctrl","alt","shift","cmd","fn"].filter { hyperMods.contains($0) }.map { sym[$0]! }.joined() + "  shortcuts") as NSString
        title.draw(at: NSPoint(x: Self.pad, y: bounds.height - Self.pad - 20),
                   withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                                    .foregroundColor: NSColor.labelColor])

        let top = bounds.height - Self.pad - 44
        for (r, row) in KeyboardLayout.rows.enumerated() {
            var x = Self.pad
            let y = top - CGFloat(r + 1) * u
            for key in row {
                let w = CGFloat(key.width) * u
                if !key.name.isEmpty {
                    drawKey(key, in: NSRect(x: x + g / 2, y: y + g / 2, width: w - g, height: u - g))
                }
                x += w
            }
        }

        guard !others.isEmpty else { return }
        var y = top - 5 * u - 26
        ("Other bindings" as NSString).draw(at: NSPoint(x: Self.pad, y: y),
            withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor])
        y -= 20
        let colW = (bounds.width - Self.pad * 2) / 2
        for (i, b) in others.enumerated() {
            let col = CGFloat(i % 2), row = CGFloat(i / 2)
            let text = "\(b.modsDescription) \(KeyboardLayout.glyph[b.keyName] ?? b.keyName.uppercased())   \(b.label)" as NSString
            text.draw(at: NSPoint(x: Self.pad + col * colW, y: y - row * 20),
                      withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                                       .foregroundColor: NSColor.labelColor])
        }
    }

    private func drawKey(_ key: KeySpec, in rect: NSRect) {
        let binding = key.code.flatMap { hyper[$0] }
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        (binding != nil ? NSColor.controlAccentColor.withAlphaComponent(0.85)
                        : NSColor.white.withAlphaComponent(0.07)).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(binding != nil ? 0.5 : 0.12).setStroke()
        path.lineWidth = 1; path.stroke()

        let cap = (KeyboardLayout.glyph[key.name] ?? key.name.uppercased()) as NSString
        let capColor = binding != nil ? NSColor.white : NSColor.white.withAlphaComponent(0.4)
        cap.draw(at: NSPoint(x: rect.minX + 7, y: rect.maxY - 18),
                 withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: capColor])

        if let binding {
            let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byWordWrapping
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
                .foregroundColor: NSColor.white, .paragraphStyle: style]
            let box = NSRect(x: rect.minX + 3, y: rect.minY + 4, width: rect.width - 6, height: rect.height - 22)
            let s = binding.label as NSString
            let h = s.boundingRect(with: box.size, options: .usesLineFragmentOrigin, attributes: attrs).height
            s.draw(in: NSRect(x: box.minX, y: box.minY + (box.height - h) / 2, width: box.width, height: h), withAttributes: attrs)
        }
    }
}

final class OverlayController {
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    let autoDismiss: TimeInterval
    let rcPath: String

    init(autoDismiss: TimeInterval, rcPath: String) { self.autoDismiss = autoDismiss; self.rcPath = rcPath }

    var onShow: (() -> Void)?
    var isVisible: Bool { panel != nil }

    func show() {
        guard panel == nil else { return }
        let bindings = SkhdParser.parse(path: rcPath)     // re-read each time: live reload
        let view = OverlayView(bindings: bindings, hyperMods: SkhdParser.detectHyper(bindings))
        let p = NSPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.level = .screenSaver; p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let fx = NSVisualEffectView(frame: view.frame)
        fx.material = .hudWindow; fx.blendingMode = .behindWindow; fx.state = .active
        fx.wantsLayer = true; fx.layer?.cornerRadius = 22; fx.layer?.masksToBounds = true
        fx.addSubview(view)
        p.contentView = fx

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        p.setFrameOrigin(NSPoint(x: screen.frame.midX - view.frame.width / 2,
                                 y: screen.frame.midY - view.frame.height / 2))
        p.alphaValue = 0; p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; p.animator().alphaValue = 1 }
        panel = p
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismiss, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        dismissTimer?.invalidate(); dismissTimer = nil
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; p.animator().alphaValue = 0 },
                                             completionHandler: { p.orderOut(nil) })
    }
}
