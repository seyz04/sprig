import SwiftUI
import ServiceManagement

let listColors: [Color] = [.orange, .pink, .blue, .teal, .purple, .green, .indigo]
func color(for list: String) -> Color { listColors[(Array(Set(Store.shared.data.todos.map(\.list))).sorted().firstIndex(of: list) ?? 0) % listColors.count] }

struct PanelView: View {
    @ObservedObject var store = Store.shared
    var openTutor: () -> Void
    @State private var draft = ""
    @State private var showLater = false
    @State private var showRoutines = false
    @State private var login = SMAppService.mainApp.status == .enabled
    @FocusState private var focused: Bool

    var lists: [String] { var seen = Set<String>(); return store.today.map(\.list).filter { seen.insert($0).inserted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
                TextField("Essay tomorrow 2pm #french", text: $draft).textFieldStyle(.plain).focused($focused)
                    .onSubmit { store.add(draft); draft = "" }
                    .accessibilityLabel("New task")
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5))).padding(12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let e = store.error { Text(e).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                    if let m = store.data.planMessage, !store.today.isEmpty { Label(m, systemImage: "leaf.fill").font(.callout).foregroundStyle(.green).fixedSize(horizontal: false, vertical: true) }
                    if store.today.isEmpty { Text(store.doneToday.isEmpty ? "Nothing for today. Add one thing above." : "All done for today.").foregroundStyle(.secondary) }
                    ForEach(lists, id: \.self) { l in section(l, color(for: l), store.today.filter { $0.list == l }) }
                    if !store.later.isEmpty {
                        DisclosureGroup("Later (\(store.later.count))", isExpanded: $showLater) { ForEach(store.later) { row($0) } }.foregroundStyle(.secondary)
                    }
                    if !store.data.routines.isEmpty {
                        DisclosureGroup("Routines", isExpanded: $showRoutines) { ForEach(store.data.routines) { routine($0) } }.foregroundStyle(.secondary)
                    }
                    if !store.doneToday.isEmpty { section("Done today", .secondary, store.doneToday) }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 12)
            }
            Divider()
            HStack {
                Button { store.planDay() } label: {
                    if store.running.contains("plan") { ProgressView().controlSize(.small) } else { Label("Plan my day", systemImage: "wand.and.stars") }
                }.disabled(store.running.contains("plan") || store.today.isEmpty)
                Spacer()
                Button(action: openTutor) { Label("Tutor", systemImage: "graduationcap") }
                Menu {
                    Toggle("Open at login", isOn: $login).onChange(of: login) { on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { login = SMAppService.mainApp.status == .enabled; store.error = error.localizedDescription }
                    }
                    Button("Edit data.json") { NSWorkspace.shared.activateFileViewerSelecting([Store.file]) }
                    Divider()
                    Button("Quit Sprig") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }.menuIndicator(.hidden).fixedSize().accessibilityLabel("Settings")
            }
            .buttonStyle(.borderless).padding(12)
        }
        .frame(width: 350, height: 480)
        .onAppear { store.importSources(); focused = true }
    }

    func section(_ title: String, _ c: Color, _ items: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(c)
            ForEach(items) { row($0) }
        }
    }

    func row(_ t: Todo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { store.toggle(t) } label: {
                Image(systemName: t.done == nil ? "circle" : "checkmark.circle.fill").font(.title3).foregroundStyle(color(for: t.list))
            }.buttonStyle(.plain).accessibilityLabel(t.done == nil ? "Mark \(t.title) done" : "Mark \(t.title) not done")
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).strikethrough(t.done != nil).foregroundStyle(t.done == nil ? .primary : .secondary).fixedSize(horizontal: false, vertical: true)
                if let s = t.step, t.done == nil { Text("First: \(s)").font(.caption).foregroundStyle(.green).fixedSize(horizontal: false, vertical: true) }
                if let d = t.due, t.done == nil { Label(when(d, t.hasTime), systemImage: "calendar").font(.caption).foregroundStyle(overdue(d, t.hasTime) ? .red : .secondary) }
            }
            Spacer(minLength: 0)
        }
        .contextMenu { Button("Delete", role: .destructive) { store.delete(t) } }
    }

    func routine(_ r: Routine) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(r.name).foregroundStyle(.primary)
                Text(String(format: "%d:%02d", r.hour, r.minute)).font(.caption)
                Spacer()
                if store.running.contains(r.id) { ProgressView().controlSize(.small) } else { Button("Run") { store.run(r) }.buttonStyle(.borderless) }
            }
            if let x = r.lastResult { Text(x).font(.caption).lineLimit(6).textSelection(.enabled) }
        }.padding(.top, 6)
    }

    func overdue(_ d: Date, _ timed: Bool) -> Bool { timed ? d < Date() : d < Calendar.current.startOfDay(for: Date()) }
    func when(_ d: Date, _ timed: Bool) -> String {
        let c = Calendar.current
        let day = c.isDateInToday(d) ? "Today" : c.isDateInTomorrow(d) ? "Tomorrow" : d.formatted(.dateTime.weekday().month().day())
        return timed ? "\(day) at \(d.formatted(date: .omitted, time: .shortened))" : day
    }
}

/// Original menu bar icon: a sprout that grows through 4 stages as today's list gets done.
func sproutIcon(_ stage: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        NSColor.black.setStroke(); NSColor.black.setFill()
        let ground = NSBezierPath(); ground.move(to: NSPoint(x: 3, y: 2.5)); ground.line(to: NSPoint(x: 15, y: 2.5)); ground.lineWidth = 1.5; ground.lineCapStyle = .round; ground.stroke()
        let top = [6.0, 9.0, 12.0, 13.0][stage]
        let stem = NSBezierPath(); stem.move(to: NSPoint(x: 9, y: 2.5)); stem.line(to: NSPoint(x: 9, y: top)); stem.lineWidth = 1.5; stem.lineCapStyle = .round; stem.stroke()
        func leaf(_ y: CGFloat, _ dx: CGFloat) {
            let p = NSBezierPath(); p.move(to: NSPoint(x: 9, y: y))
            p.curve(to: NSPoint(x: 9 + dx, y: y + 3.5), controlPoint1: NSPoint(x: 9 + dx * 0.1, y: y + 4), controlPoint2: NSPoint(x: 9 + dx * 0.6, y: y + 4.5))
            p.curve(to: NSPoint(x: 9, y: y), controlPoint1: NSPoint(x: 9 + dx, y: y + 0.5), controlPoint2: NSPoint(x: 9 + dx * 0.5, y: y - 0.5)); p.fill()
        }
        leaf(top - 2, 5)
        if stage > 0 { leaf(top - 2, -5) }
        if stage > 1 { leaf(top - 6, 5) }
        if stage > 2 { NSBezierPath(ovalIn: NSRect(x: 7, y: 13, width: 4, height: 4)).fill() }
        return true
    }
    img.isTemplate = true
    return img
}
