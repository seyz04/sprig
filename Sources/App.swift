import SwiftUI
import Combine

@main
struct Main {
    static func main() {
        if CommandLine.arguments.contains("--selftest") { selfTest(); return }
        if CommandLine.arguments.contains("--mcp") { MCP.serve(); return }
        let app = NSApplication.shared, d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(d) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = Store.shared
    var item: NSStatusItem!
    let popover = NSPopover()
    var window: NSWindow?
    var bag: AnyCancellable?

    func applicationDidFinishLaunching(_ n: Notification) {
        store.load()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self; item.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        let host = NSHostingController(rootView: PanelView(openTutor: { [weak self] in self?.openTutor() }))
        host.sizingOptions = []   // we set the size; otherwise the popover is placed before SwiftUI resizes it
        popover.contentViewController = host
        bag = store.$data.receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshIcon() }
        refreshIcon(); buildMenu()
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
        tick()
        if CommandLine.arguments.contains("--panel") { show() }
        if CommandLine.arguments.contains("--tutor") { openTutor() }
    }

    func refreshIcon() {
        let left = store.today.count, done = store.doneToday.count
        let stage = done == 0 ? 0 : left == 0 ? 3 : done * 2 >= left + done ? 2 : 1
        item.button?.image = sproutIcon(stage)
        item.button?.imagePosition = .imageLeading
        item.button?.title = left > 0 ? " \(left)" : ""
        item.button?.setAccessibilityLabel("Sprig, \(left) tasks left today")
    }

    func tick() {
        store.importInbox(); refreshIcon()
        let now = Date()
        for r in store.data.routines where r.isDue(now) { store.run(r) { [weak self] in self?.show() } }
        let pop = Routine(name: "popup", hour: store.data.popupHour, minute: store.data.popupMinute, lastRun: store.data.lastPopup)
        if pop.isDue(now) { store.data.lastPopup = now; store.save(); store.importSources(); show() }
    }

    @objc func togglePanel() { popover.isShown ? popover.performClose(nil) : show() }
    func show() {
        guard !popover.isShown, let b = item.button else { return }
        let screen = (b.window?.screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        popover.contentSize = panelSize(screen)
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        if let w = popover.contentViewController?.view.window { w.setFrame(clamp(w.frame, to: screen), display: true) }
        popover.contentViewController?.view.window?.makeKey()
    }

    func openTutor() {
        popover.performClose(nil)
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.title = "Sprig Tutor"; w.isReleasedWhenClosed = false; w.delegate = self; w.center()
            w.contentViewController = NSHostingController(rootView: TutorView()); window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ n: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool { if !f { show() }; return true }

    /// Without an Edit menu, copy and paste don't work in text fields.
    func buildMenu() {
        let main = NSMenu(), app = NSMenuItem(), edit = NSMenuItem(), a = NSMenu(), e = NSMenu(title: "Edit")
        a.addItem(withTitle: "Quit Sprig", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for (t, s, k) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { e.addItem(withTitle: t, action: Selector((s)), keyEquivalent: k) }
        app.submenu = a; edit.submenu = e; main.addItem(app); main.addItem(edit); NSApp.mainMenu = main
    }
}

/// Panel size for any Mac: 11-inch laptops up to large external displays.
func panelSize(_ s: NSRect) -> NSSize { NSSize(width: min(350, s.width - 24), height: min(max(420, s.height * 0.6), 720, s.height - 40)) }

/// Moves a frame fully inside the visible screen (hidden icons and the notch can push a popover off the edge).
func clamp(_ f: NSRect, to s: NSRect) -> NSRect {
    var r = f
    r.size.height = min(r.height, s.height)
    r.origin.x = max(s.minX, min(r.minX, s.maxX - r.width))
    r.origin.y = max(s.minY, min(r.minY, s.maxY - r.height))
    return r
}

func selfTest() {
    func check(_ c: Bool, _ m: String) { if !c { print("FAIL: \(m)"); exit(1) } }
    let cal = Calendar.current, tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
    let a = parseTodo("Essay tomorrow at 2pm #french")!
    check(a.title == "Essay" && a.list == "French" && a.hasTime, "parse: \(a)")
    check(cal.isDate(a.due!, inSameDayAs: tomorrow) && cal.component(.hour, from: a.due!) == 14, "date: \(String(describing: a.due))")
    let b = parseTodo("Buy milk")!; check(b.due == nil && b.list == "To-do" && b.title == "Buy milk", "plain")
    check(parseTodo("   ") == nil, "empty")
    let t = parseTodo("Read chapter 4 today")!; check(t.title == "Read chapter 4" && cal.isDateInToday(t.due!), "today: \(t)")
    let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
    var r = Routine(name: "x", hour: 9, minute: 0)
    check(r.isDue(noon), "due"); r.lastRun = noon; check(!r.isDue(noon.addingTimeInterval(60)), "only once")
    check(r.isDue(noon.addingTimeInterval(86400)), "next day"); check(!Routine(name: "x", hour: 13, minute: 0).isDue(noon), "not yet")
    r.lastRun = nil; r.weekdays = [cal.component(.weekday, from: noon) % 7 + 1]; check(!r.isDue(noon), "wrong weekday")
    for s in [NSRect(x: 0, y: 0, width: 1366, height: 705), NSRect(x: 0, y: 70, width: 1470, height: 853), NSRect(x: -3840, y: 200, width: 3840, height: 2100), NSRect(x: 0, y: 0, width: 300, height: 400)] {
        let z = panelSize(s)
        check(z.height <= s.height && z.width <= s.width, "fits \(s)")
        check(s.contains(clamp(NSRect(x: s.maxX - 20, y: s.maxY - 100, width: z.width, height: z.height), to: s)), "clamp \(s)")
    }
    check(Inbox.todos([["title": "  Reply to advisor ", "due": "2026-12-01T14:00", "key": "m1"]], source: "mail").first.map { $0.title == "Reply to advisor" && $0.hasTime && $0.id == "agent-mail-m1" } ?? false, "inbox")
    check(Inbox.todos([["title": ""], ["nope": 1]], source: "x").isEmpty, "inbox rejects junk")
    check(Inbox.todos(Array(repeating: ["title": String(repeating: "a", count: 999)], count: 80), source: "x").count == 50, "inbox limit")
    print("ok")
}
