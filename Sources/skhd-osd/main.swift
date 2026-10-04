import Cocoa

// Tunables
let holdTime: TimeInterval = 1.0
let autoDismiss: TimeInterval = 4.0
let rcPath = NSString(string: "~/.config/skhd/skhdrc").expandingTildeInPath

let args = CommandLine.arguments.dropFirst()

if args.contains("--dump") {
    for b in SkhdParser.parse(path: rcPath) {
        print("\(b.modsDescription)\t\(b.keyName)\t\(b.keyCode.map(String.init) ?? "-")\t\(b.label)\t\(b.command)")
    }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let overlay = OverlayController(autoDismiss: autoDismiss, rcPath: rcPath)

if args.contains("--show") {
    overlay.show()
    DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss + 0.5) { exit(0) }
    app.run()
}

if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
let watcher = HotkeyWatcher(holdTime: holdTime)
// Follow the skhdrc: the hyper combo is whichever modifier set most bindings use.
var lastMTime: Date?
func refreshHyper() {
    let resolved = (rcPath as NSString).resolvingSymlinksInPath
    let m = (try? FileManager.default.attributesOfItem(atPath: resolved)[.modificationDate]) as? Date
    guard m != lastMTime else { return }
    lastMTime = m
    watcher.setHyper(SkhdParser.detectHyper(SkhdParser.parse(path: rcPath)))
}
refreshHyper()
watcher.beforeEvent = refreshHyper
watcher.onHold = { overlay.show() }
watcher.onCancel = { if overlay.isVisible { overlay.hide() } }
guard watcher.start() else {
    FileHandle.standardError.write(Data("skhd-osd: cannot create event tap; grant Input Monitoring and relaunch\n".utf8))
    exit(1)
}
app.run()
