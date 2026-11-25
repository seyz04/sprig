# Sprig

A tiny Mac menu bar app that shows what to do today. The sprout grows as you finish things.

- **Today at a glance:** click the sprout, or let it pop up each morning.
- **Type naturally:** `Essay tomorrow 2pm #french` sets the date and the list.
- **Plan my day:** an agent orders your list and gives each task a 2-minute first step.
- **Deploy (optional):** turn it on in Settings, then press the paper plane on a task to have an agent draft it, break it down or follow your own prompt. It only writes text back. It can't send or change anything.
- **Routines:** scheduled prompts or shell commands whose results show up in the panel.
- **Tutor:** pick a notes folder and it teaches by asking questions, using your own material. It can read that folder and change nothing.

The to-do list works on its own. Planning, Deploy, prompt routines and the tutor use your own [Claude Code](https://claude.com/claude-code) login, so your task titles (and, in the tutor, the notes it reads) go to Claude.

## How it stays safe

- Plan, Deploy and prompt routines run with no tools, so they can only return text.
- The tutor gets read-only file tools, started in the notes folder you pick.
- Other agents can add tasks and list them, nothing else. What they send is length-limited and never executed.

Built by Sey Zeme with Claude Code. Ideas and bug reports are welcome in Issues.

## Install

Needs macOS 13+ and Xcode.

    git clone https://github.com/seyz04/sprig && cd sprig && ./build.sh --install

## Routines

Settings > Edit data.json, then quit Sprig first and reopen it after saving. Commands run as you, so only add ones you trust.

    "routines": [{"id": "am", "name": "Top 3", "hour": 8, "minute": 30, "weekdays": [2,3,4,5,6], "enabled": true, "prompt": "Pick my top 3."}]

`weekdays`: 1 is Sunday, empty is every day. Use `"command"` instead of `"prompt"` for a shell command. Sprig must be running.

## Connect your agents

Sprig includes a small MCP server. Agents can add tasks and read today's list. They can't edit, delete or run anything.

Claude Code plugin (adds the server and an `email-to-sprig` skill):

    /plugin marketplace add seyz04/sprig
    /plugin install sprig@sprig

Any other MCP client:

    {"mcpServers": {"sprig": {"command": "/Applications/Sprig.app/Contents/MacOS/Sprig", "args": ["--mcp"]}}}

Then ask for "an email run into Sprig", or put that in a scheduled agent. The skill uses your own mail connector and only reads.

## Credits

MIT license. The tutor is adapted from Jane Street's [socratic-tutor](https://github.com/janestreet/agent_skills) (MIT, see `Resources/`).
