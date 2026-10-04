import Foundation

struct KeySpec { let name: String; let code: Int?; let width: Double }

/// ANSI keyboard rows; `code == nil` is a spacer (width only) or an unbindable key.
enum KeyboardLayout {
    static func k(_ n: String, _ w: Double = 1) -> KeySpec { KeySpec(name: n, code: SkhdParser.keyCodes[n], width: w) }
    static func gap(_ w: Double) -> KeySpec { KeySpec(name: "", code: nil, width: w) }
    static func plain(_ n: String, _ w: Double) -> KeySpec { KeySpec(name: n, code: nil, width: w) }

    static let rows: [[KeySpec]] = [
        ["`","1","2","3","4","5","6","7","8","9","0","-","="].map { k($0) } + [KeySpec(name: "backspace", code: 51, width: 1.5)],
        [plain("tab", 1.5)] + ["q","w","e","r","t","y","u","i","o","p","[","]","\\"].map { k($0) },
        [plain("caps", 1.75)] + ["a","s","d","f","g","h","j","k","l",";","'"].map { k($0) } + [KeySpec(name: "return", code: 36, width: 1.75)],
        [plain("shift", 2.25)] + ["z","x","c","v","b","n","m",",",".","/"].map { k($0) } + [plain("shift", 2.25)],
        [gap(3.5), KeySpec(name: "space", code: 49, width: 6), gap(0.5), k("left"), k("up"), k("down"), k("right")],
    ]

    static let glyph: [String: String] = [
        "return": "⏎", "backspace": "⌫", "tab": "⇥", "space": "␣", "escape": "⎋",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "caps": "⇪", "shift": "⇧",
    ]
}
