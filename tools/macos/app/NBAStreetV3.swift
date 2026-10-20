// NBA Street V3 launcher for macOS: the ready-to-play app (no compiling). Asks for the player's ISO once, checks that
// it is the disc the game was recompiled from, then starts the recompiled runner with PCSX2's GS host (Metal).
// The ISO is mounted read-only while the game runs (the game reads the disc from there); the memory card, graphics
// settings and logs live in ~/Library/Application Support/NBAStreetV3, so the app itself can stay read-only.
// Build: tools/macos/app/build_launcher.sh (swiftc, Xcode command line tools).
import AppKit
import CryptoKit

// SHA-256 of SLUS_211.26 (NBA Street V3 USA): the game code in ps2EntryRunner was recompiled from exactly this ELF.
let elfSha256 = "d8ecae84a16f8afe930fb29aff5cb4ca88c35d8c92a3f6a4fbb9219b692aa937"
let elfName = "SLUS_211.26"
let onlineServer = ProcessInfo.processInfo.environment["NBA_SERVER"] ?? "nbas3.xellrecomp.party"

// MARK: - ISO 9660 (root directory only: enough to find and check the ELF)

final class Iso9660 {
    struct Entry { let name: String; let lba: UInt64; let size: UInt64; let isDir: Bool }
    private let fh: FileHandle
    private(set) var rootLba: UInt64 = 0
    private(set) var rootSize: UInt64 = 0

    init(path: String) throws {
        guard let h = FileHandle(forReadingAtPath: path) else { throw err("Could not open the ISO.") }
        fh = h
        let pvd = try read(16 * 2048, 2048)
        guard pvd.count == 2048, pvd[0] == 1, String(bytes: pvd[1..<6], encoding: .ascii) == "CD001" else {
            throw err("This file is not an ISO 9660 image (PS2 DVD).")
        }
        let root = pvd[156..<(156 + 34)]
        rootLba = UInt64(le32(root, 2))
        rootSize = UInt64(le32(root, 10))
    }
    deinit { try? fh.close() }

    func read(_ offset: UInt64, _ count: Int) throws -> Data {
        try fh.seek(toOffset: offset)
        return try fh.read(upToCount: count) ?? Data()
    }

    func list(_ lba: UInt64, _ size: UInt64) throws -> [Entry] {
        let d = try read(lba * 2048, Int(size))
        var out: [Entry] = []
        var sector = 0
        while sector < d.count {
            var p = sector
            while p < min(sector + 2048, d.count) {
                let len = Int(d[d.startIndex + p])
                if len == 0 { break }
                let nameLen = Int(d[d.startIndex + p + 32])
                let flags = d[d.startIndex + p + 25]
                let nameBytes = d[(d.startIndex + p + 33)..<(d.startIndex + p + 33 + nameLen)]
                if !(nameLen == 1 && (nameBytes.first == 0 || nameBytes.first == 1)) {
                    var name = String(bytes: nameBytes, encoding: .ascii) ?? ""
                    if let semi = name.firstIndex(of: ";") { name = String(name[..<semi]) }
                    if name.hasSuffix(".") { name.removeLast() }
                    out.append(Entry(name: name, lba: UInt64(le32(d, p + 2)), size: UInt64(le32(d, p + 10)),
                                     isDir: (flags & 2) != 0))
                }
                p += len
            }
            sector += 2048
        }
        return out
    }

    func readFile(_ e: Entry) throws -> Data { try read(e.lba * 2048, Int(e.size)) }

    private func le32(_ d: Data, _ o: Int) -> UInt32 {
        let b = d.startIndex + o
        return UInt32(d[b]) | UInt32(d[b + 1]) << 8 | UInt32(d[b + 2]) << 16 | UInt32(d[b + 3]) << 24
    }
}

func err(_ msg: String) -> NSError { NSError(domain: "NBA", code: 1, userInfo: [NSLocalizedDescriptionKey: msg]) }

// MARK: - Paths

struct Paths {
    let bundle = Bundle.main
    var macos: URL { bundle.executableURL!.deletingLastPathComponent() }
    var res: URL { bundle.resourceURL! }
    let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NBAStreetV3", isDirectory: true)
    var mc0: URL { support.appendingPathComponent("mc0", isDirectory: true) }
    var gshost: URL { support.appendingPathComponent("gshost", isDirectory: true) }
    var logs: URL { support.appendingPathComponent("logs", isDirectory: true) }
}

// Resolutions: one ini each, so what the in-game F1 menu changes is kept per resolution.
struct Quality { let title: String; let ini: String }
let qualities = [
    Quality(title: "4K (6x) - M Max / Ultra", ini: "nba_street_6x.ini"),
    Quality(title: "1440p (4x) - M Pro", ini: "nba_street_4x.ini"),
    Quality(title: "1080p (3x) - any Mac", ini: "nba_street.ini"),
    Quality(title: "720p (2x) - lightest", ini: "nba_street_2x.ini"),
]

func defaultQuality() -> Int {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var buf = [CChar](repeating: 0, count: max(size, 1))
    sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
    let chip = String(cString: buf)
    if chip.contains("Max") || chip.contains("Ultra") { return 0 }
    if chip.contains("Pro") { return 1 }
    return 2
}

// MARK: - Window

final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let paths = Paths()
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "")
    let pick = NSButton(title: "Browse…", target: nil, action: nil)
    let play = NSButton(title: "PLAY", target: nil, action: nil)
    let quality = NSPopUpButton(frame: .zero, pullsDown: false)
    let online = NSButton(checkboxWithTitle: "Online play (community server \(onlineServer))", target: nil, action: nil)
    let fullscreen = NSButton(checkboxWithTitle: "Fullscreen (Option+Return or Ctrl+Cmd+F switches in game)",
                              target: nil, action: nil)
    var isoPath = ""
    var isoChecked = false
    var direct = false
    var game: Process?
    var mountPoint: String?
    let prefs = UserDefaults.standard

    func applicationDidFinishLaunching(_ n: Notification) {
        let args = CommandLine.arguments
        direct = args.contains("--play")
        buildWindow()
        loadConfig()
        if let i = args.firstIndex(of: "--iso"), i + 1 < args.count { useIso(args[i + 1]) }
        refreshState()
        if direct && gameReady() {
            startGame()
        } else {
            direct = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { game == nil }

    func applicationShouldTerminate(_ s: NSApplication) -> NSApplication.TerminateReply {
        if let g = game, g.isRunning { g.terminate(); g.waitUntilExit() }
        unmountIso()
        return .terminateNow
    }

    func label(_ text: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        return l
    }

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 430),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "NBA Street V3 - Mac"
        window.delegate = self
        window.center()
        let v = window.contentView!

        let title = label("NBA Street V3", size: 24, bold: true)
        let sub = label("Recompiled for Mac - you need your own NBA Street V3 USA ISO (SLUS-21126)", size: 12)
        sub.textColor = .secondaryLabelColor

        pick.target = self; pick.action = #selector(pickIso)
        play.target = self; play.action = #selector(startGame)
        play.font = .boldSystemFont(ofSize: 18)
        play.bezelStyle = .rounded
        play.keyEquivalent = "\r"
        status.maximumNumberOfLines = 3

        for q in qualities { quality.addItem(withTitle: q.title) }
        quality.target = self; quality.action = #selector(saveConfig)
        online.target = self; online.action = #selector(saveConfig)
        fullscreen.target = self; fullscreen.action = #selector(saveConfig)

        let help = label("Controller (Xbox, PlayStation or MFi): A = Cross, B = Circle, X = Square, Y = Triangle.\n" +
                         "Keyboard: arrows = d-pad, WASD = left stick, Z/X/C/V = Square/Cross/Circle/Triangle,\n" +
                         "Q/E = L1/R1, 1/3 = L2/R2, Return = START. F1 (or hold START 1.5 s) = graphics menu.", size: 11)
        help.textColor = .secondaryLabelColor
        let folder = NSButton(title: "Saves and logs…", target: self, action: #selector(openSupport))
        folder.bezelStyle = .rounded
        let site = NSButton(title: "github.com/recomp-code/street-recomp-v3", target: self, action: #selector(openSite))
        site.bezelStyle = .inline

        let place: [(NSView, NSRect)] = [
            (title, NSRect(x: 20, y: 378, width: 560, height: 34)),
            (sub, NSRect(x: 22, y: 358, width: 560, height: 18)),
            (status, NSRect(x: 22, y: 300, width: 430, height: 48)),
            (pick, NSRect(x: 460, y: 312, width: 120, height: 32)),
            (label("Resolution:"), NSRect(x: 22, y: 262, width: 80, height: 20)),
            (quality, NSRect(x: 104, y: 256, width: 476, height: 28)),
            (online, NSRect(x: 22, y: 226, width: 560, height: 20)),
            (fullscreen, NSRect(x: 22, y: 200, width: 560, height: 20)),
            (help, NSRect(x: 22, y: 120, width: 560, height: 60)),
            (folder, NSRect(x: 18, y: 70, width: 170, height: 30)),
            (site, NSRect(x: 22, y: 30, width: 300, height: 24)),
            (play, NSRect(x: 420, y: 22, width: 160, height: 56)),
        ]
        for (view, frame) in place { view.frame = frame; v.addSubview(view) }
    }

    // MARK: config

    func loadConfig() {
        isoPath = prefs.string(forKey: "iso") ?? ""
        isoChecked = prefs.string(forKey: "isoChecked") == isoPath && !isoPath.isEmpty
        let q = prefs.object(forKey: "quality") as? Int ?? defaultQuality()
        quality.selectItem(at: (0..<qualities.count).contains(q) ? q : defaultQuality())
        online.state = (prefs.object(forKey: "online") as? Bool ?? true) ? .on : .off
        fullscreen.state = (prefs.object(forKey: "fullscreen") as? Bool ?? true) ? .on : .off
    }

    @objc func saveConfig() {
        prefs.set(isoPath, forKey: "iso")
        prefs.set(isoChecked ? isoPath : "", forKey: "isoChecked")
        prefs.set(quality.indexOfSelectedItem, forKey: "quality")
        prefs.set(online.state == .on, forKey: "online")
        prefs.set(fullscreen.state == .on, forKey: "fullscreen")
    }

    func gameReady() -> Bool { isoChecked && FileManager.default.fileExists(atPath: isoPath) }

    func refreshState() {
        if gameReady() {
            status.stringValue = "Ready. ISO: " + isoPath
        } else if !isoPath.isEmpty && !FileManager.default.fileExists(atPath: isoPath) {
            status.stringValue = "ISO not found (\(isoPath)). Choose it again."
        } else {
            status.stringValue = "First choose your NBA Street V3 ISO (USA, SLUS-21126)."
        }
        play.isEnabled = gameReady()
    }

    // MARK: ISO

    func check(_ iso: String) throws {
        let img = try Iso9660(path: iso)
        let top = try img.list(img.rootLba, img.rootSize)
        guard let elf = top.first(where: { $0.name.caseInsensitiveCompare(elfName) == .orderedSame }) else {
            throw err("This ISO is not NBA Street V3 USA (no \(elfName) on it).")
        }
        let sum = SHA256.hash(data: try img.readFile(elf)).map { String(format: "%02x", $0) }.joined()
        guard sum == elfSha256 else {
            throw err("This is another version of the game: the app is recompiled for NBA Street V3 USA (SLUS-21126).")
        }
    }

    func useIso(_ path: String) {
        do {
            try check(path)
            isoPath = path
            isoChecked = true
            saveConfig()
        } catch {
            alert("ISO not valid", error.localizedDescription)
        }
        refreshState()
    }

    @objc func pickIso() {
        let dlg = NSOpenPanel()
        dlg.title = "Choose your NBA Street V3 ISO (SLUS-21126)"
        dlg.allowsOtherFileTypes = true
        if !isoPath.isEmpty { dlg.directoryURL = URL(fileURLWithPath: isoPath).deletingLastPathComponent() }
        dlg.beginSheetModal(for: window) { r in
            if r == .OK, let u = dlg.url { self.useIso(u.path) }
        }
    }

    // The game reads the disc from the mounted ISO (read-only, not shown in Finder).
    func mountIso() throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["attach", "-readonly", "-nobrowse", "-noverify", "-noautoopen", "-plist", isoPath]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try p.run()
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: out, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mp = entities.compactMap({ $0["mount-point"] as? String }).first else {
            throw err("macOS could not mount the ISO (hdiutil attach).")
        }
        return mp
    }

    func unmountIso() {
        guard let mp = mountPoint else { return }
        mountPoint = nil
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["detach", mp, "-quiet"]
        try? p.run()
        p.waitUntilExit()
    }

    // MARK: play

    // the app's files may be read-only (a downloaded app runs from a read-only copy): copy the bytes, not the permissions
    func copyWritable(_ src: URL, _ dst: URL) throws {
        try Data(contentsOf: src).write(to: dst)
    }

    func setupSupport(_ ini: URL, _ q: Quality) throws {
        let fm = FileManager.default
        for d in [paths.mc0, paths.gshost, paths.logs] { try fm.createDirectory(at: d, withIntermediateDirectories: true) }
        // network configuration on the memory card (once)
        let net = paths.mc0.appendingPathComponent("BWNETCNF", isDirectory: true)
        if !fm.fileExists(atPath: net.appendingPathComponent("BWNETCNF").path) {
            try fm.createDirectory(at: net, withIntermediateDirectories: true)
            let src = paths.res.appendingPathComponent("mc0_netcnf/BWNETCNF")
            for f in try fm.contentsOfDirectory(atPath: src.path) {
                try copyWritable(src.appendingPathComponent(f), net.appendingPathComponent(f))
            }
        }
        if !fm.fileExists(atPath: ini.path) {
            try copyWritable(paths.res.appendingPathComponent("presets/" + q.ini), ini)
        }
    }

    @objc func startGame() {
        guard gameReady() else { refreshState(); return }
        saveConfig()
        let q = qualities[quality.indexOfSelectedItem]
        let ini = paths.gshost.appendingPathComponent(q.ini)
        let mp: String
        do {
            try setupSupport(ini, q)
            mp = try mountIso()
        } catch {
            alert("Could not prepare the game", error.localizedDescription)
            return
        }
        mountPoint = mp

        let p = Process()
        // the runner lives in a helper app (LSUIElement): it has no window of its own, so no Dock icon either
        p.executableURL = paths.bundle.bundleURL.appendingPathComponent("Contents/Helpers/Game.app/Contents/MacOS/ps2EntryRunner")
        p.arguments = [mp + "/" + elfName]
        p.currentDirectoryURL = paths.support
        var env = ProcessInfo.processInfo.environment
        env["PS2X_GS_LIVE"] = "1"
        env["PS2X_MC_ROOT"] = paths.mc0.path
        env["PS2X_CD_IMAGE"] = isoPath // raw sector reads (the files come from the mounted ISO)
        if online.state == .on {
            env["PS2X_NET"] = "1"
            env["PS2X_NET_SERVER"] = onlineServer
        }
        env["PS2X_GSHOST"] = paths.macos.appendingPathComponent("pcsx2-gsrunner").path
        env["PS2X_GSHOST_ARGS"] = "-ini \"\(ini.path)\"" + (fullscreen.state == .on ? " -fullscreen" : "")
        p.environment = env
        let log = paths.logs.appendingPathComponent("play.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: log) { p.standardOutput = h; p.standardError = h }
        let started = Date()
        p.terminationHandler = { proc in
            DispatchQueue.main.async { self.gameEnded(proc, log: log, seconds: Date().timeIntervalSince(started)) }
        }
        do { try p.run() } catch {
            unmountIso()
            alert("Could not start the game", error.localizedDescription)
            return
        }
        game = p
        window.orderOut(nil)
        // while the game runs, its window (PCSX2) is the only Dock icon
        NSApp.setActivationPolicy(.accessory)
    }

    func gameEnded(_ p: Process, log: URL, seconds: TimeInterval) {
        game = nil
        NSApp.setActivationPolicy(.regular)
        unmountIso()
        let code = p.terminationStatus
        let failed = code != 0 && p.terminationReason == .exit || p.terminationReason == .uncaughtSignal
        if direct && !failed { NSApp.terminate(nil); return }
        direct = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if failed {
            let how = p.terminationReason == .uncaughtSignal ? "signal \(code)" : "exit code \(code)"
            alert("NBA Street V3", "The game closed (\(how)) after \(Int(seconds)) s.\nLog: \(log.path)")
        }
    }

    // MARK: misc

    @objc func openSupport() {
        try? FileManager.default.createDirectory(at: paths.support, withIntermediateDirectories: true)
        NSWorkspace.shared.open(paths.support)
    }

    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://github.com/recomp-code/street-recomp-v3")!) }

    func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        if window.isVisible { a.beginSheetModal(for: window) } else { a.runModal() }
    }

    // an ISO dropped on the app icon
    func application(_ app: NSApplication, open urls: [URL]) {
        if let u = urls.first(where: { $0.pathExtension.lowercased() == "iso" }) { useIso(u.path) }
    }
}

let app = NSApplication.shared
let delegate = Launcher()
app.delegate = delegate
app.setActivationPolicy(.regular)
// menu bar: Quit (Cmd+Q)
let mainMenu = NSMenu()
let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Quit NBA Street V3", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = appMenu
app.mainMenu = mainMenu
app.run()
