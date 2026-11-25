import Foundation

struct AgentError: LocalizedError { let errorDescription: String? ; init(_ s: String) { errorDescription = s } }

/// Runs the user's own Claude Code login. No API key, no server.
enum Agent {
    static var path: String? {
        let home = NSHomeDirectory()
        return ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `tools` is empty by default, so the agent can only return text. The tutor passes read-only tools.
    static func run(_ prompt: String, system: String, tools: String = "", cwd: URL? = nil, session: (id: String, resume: Bool)? = nil,
                    completion: @escaping (Result<String, Error>) -> Void) {
        guard let exe = path else { return completion(.failure(AgentError("Claude Code isn't installed. The to-do list still works without it."))) }
        var args = ["-p", "--model", "sonnet", "--tools", tools, "--setting-sources", "", "--strict-mcp-config", "--disable-slash-commands", "--system-prompt", system]
        if let s = session { args += [s.resume ? "--resume" : "--session-id", s.id] } else { args.append("--no-session-persistence") }
        exec(exe, args, input: prompt, cwd: cwd ?? FileManager.default.temporaryDirectory, completion: completion)
    }

    static func exec(_ exe: String, _ args: [String], input: String? = nil, cwd: URL? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process(), out = Pipe(), inn = Pipe()
            p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
            if let cwd { p.currentDirectoryURL = cwd }
            p.standardOutput = out; p.standardError = out; p.standardInput = inn
            let done: (Result<String, Error>) -> Void = { r in DispatchQueue.main.async { completion(r) } }
            do { try p.run() } catch { return done(.failure(error)) }
            let timeout = DispatchWorkItem { if p.isRunning { p.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: timeout)
            if let input { try? inn.fileHandleForWriting.write(contentsOf: Data(input.utf8)) }
            try? inn.fileHandleForWriting.close()
            let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            p.waitUntilExit(); timeout.cancel()
            done(p.terminationStatus == 0 ? .success(text) : .failure(AgentError(text.isEmpty ? "It stopped or took over 5 minutes." : String(text.suffix(300)))))
        }
    }
}
