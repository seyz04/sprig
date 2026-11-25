import Foundation

/// Queue that other agents write to. The app picks files up within 30 seconds.
enum Inbox {
    static let dir = Store.dir.appendingPathComponent("inbox")
    static var decoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }

    /// Turns untrusted agent input into plain to-dos: length-limited text, 50 at most.
    static func todos(_ raw: [[String: Any]], source: String) -> [Todo] {
        let src = clean(source, 24)
        return raw.prefix(50).compactMap { o in
            let title = clean(o["title"] as? String ?? "", 160)
            guard !title.isEmpty else { return nil }
            var t = Todo(title: title, list: clean(o["list"] as? String ?? "Inbox", 24))
            if t.list.isEmpty { t.list = "Inbox" }
            if let d = o["due"] as? String {
                let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
                for (fmt, timed) in [("yyyy-MM-dd'T'HH:mm", true), ("yyyy-MM-dd'T'HH:mm:ss", true), ("yyyy-MM-dd", false)] {
                    f.dateFormat = fmt
                    if let x = f.date(from: d) { t.due = x; t.hasTime = timed; break }
                }
            }
            let note = clean(o["note"] as? String ?? "", 200)
            t.note = note.isEmpty ? nil : note
            t.source = src.isEmpty ? "agent" : src
            if let k = o["key"] as? String, !k.isEmpty { t.id = "agent-\(t.source!)-\(clean(k, 80))" }   // same key = same task, never doubled
            return t
        }
    }

    static func clean(_ s: String, _ n: Int) -> String {
        String(s.components(separatedBy: .controlCharacters).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).prefix(n))
    }

    static func put(_ items: [Todo]) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        try e.encode(items).write(to: dir.appendingPathComponent(UUID().uuidString + ".json"), options: .atomic)
    }
}

/// `Sprig --mcp`: a small MCP server on stdin/stdout. It can add tasks and list them. It can't edit, delete or run anything.
enum MCP {
    static let tools: [[String: Any]] = [
        ["name": "add_tasks", "description": "Add to-dos to the user's Sprig menu bar list. Only real actions the user must take.",
         "inputSchema": ["type": "object", "required": ["tasks"], "properties": [
            "source": ["type": "string", "description": "Short name of where these came from, e.g. mail"],
            "tasks": ["type": "array", "maxItems": 50, "items": ["type": "object", "required": ["title"], "properties": [
                "title": ["type": "string"], "due": ["type": "string", "description": "Local yyyy-MM-dd or yyyy-MM-ddTHH:mm. Leave out if unknown."],
                "list": ["type": "string"], "note": ["type": "string"], "key": ["type": "string", "description": "Stable id such as the message id, so reruns don't add duplicates"]]]]]]],
        ["name": "list_today", "description": "List the user's open Sprig tasks due today or undated.", "inputSchema": ["type": "object", "properties": [String: Any]()]],
    ]

    static func serve() {
        while let line = readLine() {
            guard let m = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], let method = m["method"] as? String else { continue }
            guard let id = m["id"] else { continue }   // notifications need no reply
            let p = m["params"] as? [String: Any] ?? [:]
            var reply: [String: Any] = ["jsonrpc": "2.0", "id": id]
            switch method {
            case "initialize": reply["result"] = ["protocolVersion": p["protocolVersion"] as? String ?? "2025-06-18", "capabilities": ["tools": [String: Any]()], "serverInfo": ["name": "sprig", "version": "0.3"]]
            case "ping": reply["result"] = [String: Any]()
            case "tools/list": reply["result"] = ["tools": tools]
            case "tools/call":
                let (text, bad) = call(p["name"] as? String ?? "", p["arguments"] as? [String: Any] ?? [:])
                reply["result"] = ["content": [["type": "text", "text": text]], "isError": bad]
            default: reply["error"] = ["code": -32601, "message": "Unknown method"]
            }
            if let d = try? JSONSerialization.data(withJSONObject: reply) { FileHandle.standardOutput.write(d + Data("\n".utf8)) }
        }
    }

    static func call(_ name: String, _ a: [String: Any]) -> (String, Bool) {
        switch name {
        case "add_tasks":
            let items = Inbox.todos(a["tasks"] as? [[String: Any]] ?? [], source: a["source"] as? String ?? "agent")
            guard !items.isEmpty else { return ("No valid tasks. Each needs a title.", true) }
            do { try Inbox.put(items); return ("Queued \(items.count). They show up in Sprig within 30 seconds if it's open.", false) } catch { return (error.localizedDescription, true) }
        case "list_today":
            guard let raw = try? Data(contentsOf: Store.file), let d = try? Inbox.decoder.decode(AppData.self, from: raw) else { return ("Sprig has no data yet.", true) }
            Store.shared.data = d
            let t = Store.shared.today
            return (t.isEmpty ? "Nothing open today." : t.map { "- \($0.title) [\($0.list)]" }.joined(separator: "\n"), false)
        default: return ("Unknown tool", true)
        }
    }
}
