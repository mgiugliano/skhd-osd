import Foundation

struct Binding {
    var mods: Set<String>      // normalised: alt, cmd, shift, ctrl, fn
    var keyName: String
    var keyCode: Int?
    var command: String
    var label: String

    var modsDescription: String {
        let order = ["ctrl", "alt", "shift", "cmd", "fn"]
        let sym = ["ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘", "fn": "fn"]
        return order.filter { mods.contains($0) }.map { sym[$0]! }.joined()
    }
}

enum SkhdParser {
    static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "return": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "backspace": 51, "escape": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    static func normaliseMods(_ s: String) -> Set<String> {
        var out = Set<String>()
        for raw in s.split(separator: "+") {
            switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
            case "alt", "lalt", "ralt": out.insert("alt")
            case "cmd", "lcmd", "rcmd": out.insert("cmd")
            case "shift", "lshift", "rshift": out.insert("shift")
            case "ctrl", "lctrl", "rctrl": out.insert("ctrl")
            case "fn": out.insert("fn")
            case "hyper": out.formUnion(["alt", "cmd", "shift", "ctrl"])
            case "meh": out.formUnion(["alt", "shift", "ctrl"])
            default: break
            }
        }
        return out
    }

    /// The modifier set used by most bindings: treated as the "hyper" key.
    static func detectHyper(_ bindings: [Binding]) -> Set<String> {
        var counts: [Set<String>: Int] = [:]
        for b in bindings where !b.mods.isEmpty { counts[b.mods, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? ["alt", "cmd"]
    }

    static func parse(path: String) -> [Binding] {
        let resolved = (path as NSString).resolvingSymlinksInPath
        guard let text = try? String(contentsOfFile: resolved, encoding: .utf8) else { return [] }
        var result: [Binding] = []
        var pendingComment: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { pendingComment = nil; continue }
            if line.hasPrefix("#") {
                let body = line.drop(while: { $0 == "#" || $0 == " " })
                pendingComment = body.lowercased().hasPrefix("osd:") ? String(body.dropFirst(4)).trimmingCharacters(in: .whitespaces) : nil
                continue
            }
            // "<mods> - <key> : <command>"; skip mode declarations, blacklists, etc.
            guard let colon = line.firstIndex(of: ":"),
                  line.hasPrefix(where: { $0.isLetter || $0.isNumber }) else { pendingComment = nil; continue }
            let left = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let command = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard let dash = left.range(of: " - ") ?? left.range(of: "-", options: .backwards) else { continue }
            let mods = normaliseMods(String(left[..<dash.lowerBound]))
            let key = String(left[dash.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            var code = keyCodes[key]
            if code == nil, key.hasPrefix("0x") { code = Int(key.dropFirst(2), radix: 16) }
            let label = pendingComment ?? deriveLabel(command)
            pendingComment = nil
            result.append(Binding(mods: mods, keyName: key, keyCode: code, command: command, label: label))
        }
        return result
    }

    // MARK: - Labels

    static func deriveLabel(_ command: String) -> String {
        let tokens = command.split(separator: " ").map(String.init)
        guard let first = tokens.first else { return "?" }
        let exe = (first as NSString).lastPathComponent

        switch exe {
        case "yabai": return yabaiLabel(Array(tokens.dropFirst()))
        case "open":
            if let i = tokens.firstIndex(where: { $0.hasPrefix("-") && $0.contains("a") }), i + 1 < tokens.count {
                var name = tokens[(i + 1)...].prefix(while: { !$0.hasPrefix("-") }).joined(separator: " ")
                name = name.replacingOccurrences(of: "\\", with: "")
                // stop at next flag-ish token if any
                name = (name as NSString).lastPathComponent
                return name.replacingOccurrences(of: ".app", with: "")
            }
            return "open"
        case "code": return "VS Code"
        case "movewindow.sh":
            let d = ["up": "↑", "down": "↓", "left": "←", "right": "→", "upleft": "↖", "upright": "↗",
                     "downleft": "↙", "downright": "↘", "center": "◎"]
            return "move " + (tokens.dropFirst().first.flatMap { d[$0] } ?? "")
        default:
            var base = (exe as NSString).deletingPathExtension
            if let arg = tokens.dropFirst().first, !arg.hasPrefix("-") { base += " " + arg }
            return base
        }
    }

    static func yabaiLabel(_ t: [String]) -> String {
        let arrows = ["west": "←", "east": "→", "north": "↑", "south": "↓"]
        if t.first == "-m" {
            let rest = Array(t.dropFirst())
            if let f = rest.firstIndex(of: "--focus"), f + 1 < rest.count {
                return "focus " + (arrows[rest[f + 1]] ?? rest[f + 1])
            }
            if let f = rest.firstIndex(of: "--toggle"), f + 1 < rest.count {
                return "toggle " + rest[f + 1].replacingOccurrences(of: "native-", with: "")
            }
            if let f = rest.firstIndex(of: "--mirror"), f + 1 < rest.count { return "mirror " + rest[f + 1] }
            if rest.contains("--rotate") { return "rotate" }
            if rest.contains("--balance") { return "balance" }
            return rest.dropFirst().joined(separator: " ")
        }
        if let f = t.first { return f.replacingOccurrences(of: "--", with: "").replacingOccurrences(of: "-service", with: "") + " yabai" }
        return "yabai"
    }
}

extension String {
    func hasPrefix(where p: (Character) -> Bool) -> Bool { first.map(p) ?? false }
}
