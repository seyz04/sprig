# Sprig

A tiny Mac menu bar app that shows what to do today. The sprout grows as you finish things.

- **Today at a glance:** click the sprout, or let it pop up each morning.
- **Type naturally:** `Essay tomorrow 2pm #french` sets the date and the list.
- **Plan my day:** an agent orders your list and gives each task a 2-minute first step.
- **Routines:** scheduled prompts or shell commands whose results show up in the panel.
- **Tutor:** pick a notes folder and it teaches by asking questions, using your own material. It can read that folder and change nothing.

The to-do list works on its own. Planning, prompt routines and the tutor use your own [Claude Code](https://claude.com/claude-code) login, so your task titles (and, in the tutor, the notes it reads) go to Claude.

## Install

Needs macOS 13+ and Xcode.

    git clone https://github.com/seyz04/sprig && cd sprig && ./build.sh --install

## Routines

Settings > Edit data.json, then quit Sprig first and reopen it after saving. Commands run as you, so only add ones you trust.

    "routines": [{"id": "am", "name": "Top 3", "hour": 8, "minute": 30, "weekdays": [2,3,4,5,6], "enabled": true, "prompt": "Pick my top 3."}]

`weekdays`: 1 is Sunday, empty is every day. Use `"command"` instead of `"prompt"` for a shell command. Sprig must be running.

## Credits

MIT license. The tutor is adapted from Jane Street's [socratic-tutor](https://github.com/janestreet/agent_skills) (MIT, see `Resources/`).
