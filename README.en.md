# speckit-auto-agents

A small set of [Claude Code](https://claude.com/claude-code) subagent definitions that run [Spec-Kit](https://github.com/github/spec-kit) skills in an automated loop, following **Spec-Driven Development (SDD)**. A CLI script, `add-agents`, copies the agents you need into any project.

> **Note:** This project is fully vibecoded. Read the agent prompts and scripts before trusting them with your codebase.

## What's inside

```
.
├── add-agents      # CLI: copies agent markdowns into a project
├── install.sh      # installs add-agents + agent files, checks Spec-Kit
└── agents/
    ├── coordinator.md      # orchestrator, the only agent that talks to the user
    ├── planner.md          # specify → plan → tasks (+ checklists)
    ├── developer.md        # implements tasks.md
    ├── verifier.md         # analyze + converge, never fixes
    ├── bug-fixer.md        # assess → fix → test a bug
    ├── idea-assessor.md    # intake → research → define → shape → decide
    └── AGENTS.md           # shared rules: artifact layering, reply format, missing skills
```

## The agents

| Agent | Role | Spec-Kit skills |
|-------|------|-----------------|
| `coordinator` | Routes work, owns user interaction. Never writes code, plans or reports. | `speckit-constitution`, `speckit-clarify` |
| `planner` | Writes `spec.md`, `plan.md`, `tasks.md`, checklists under `specs/<feature>/`. | `speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-checklist` |
| `developer` | Implements tasks, runs tests, commits on the feature branch. | `speckit-implement` |
| `verifier` | Judges artifacts and code. Read-only on source. | `speckit-analyze`, `speckit-converge` |
| `bug-fixer` | One stage per call, state kept in `.specify/bugs/<slug>/`. | `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` |
| `idea-assessor` | One stage per call, state kept in `.specify/assessments/<slug>/`. | `speckit-assess-intake`, `-research`, `-define`, `-shape`, `-decide` |

Each agent has narrow permissions (tools, writable paths) and answers with a fixed `STATUS` block, so the coordinator reads little and its context stays small.

Shared rules live in `AGENTS.md` (installed at the project root) instead of being repeated in every agent:

- **Artifact layering.** constitution → spec → plan → tasks. Each file holds only what is new at its level and refers upstream by ID (`FR-003`, `constitution §Testing`) instead of restating it. `tasks.md` is the checklist only.
- **Compact replies.** Agents answer with the `STATUS` block only: paths and IDs, no prose.
- **Missing skills.** Agents never improvise a skill they don't own; they return `SKILL_REQUEST`.

## Workflows

The `coordinator` picks one based on your request.

### SDD loop (new feature)

```
planner: specify
   └─ [NEEDS CLARIFICATION]? → coordinator: clarify with user
planner: plan → tasks
verifier: analyze      ── CRITICAL? → back to planner
developer: implement
verifier: converge     ── Converged → done
                       └─ code findings → developer
                       └─ spec/plan/tasks findings → planner → developer
```

Stops after 5 implement→converge rounds without progress and escalates to you.

### Bug loop

`assess → fix → test`, one `bug-fixer` call per stage. The verdict is `verified`, `partial` or `failed`. `partial` retries fix/test, `failed` re-assesses. Max 2 retries, then it escalates.

### Assessment loop (idea evaluation)

`intake → research → define → shape → decide`, ending in `go`, `needs-clarification` or `kill`. A `go` only recommends: you decide whether to build, and the SDD loop starts from `decision.md`.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- [Spec-Kit](https://github.com/github/spec-kit) (`specify` CLI), installed with `uv tool install specify-cli`
- The Spec-Kit skills the agents reference, installed in the target project (the agents stop with a `SKILL_REQUEST` if one is missing, they don't improvise)
- Bash

## Install

From the repo root:

```bash
./install.sh
```

It:

1. Validates that all files exist, are non-empty, and that the agent files start with frontmatter.
2. Checks `add-agents` for syntax errors and that its `AGENTS_SRC_DIR` matches the install location.
3. Copies `add-agents` to `~/.local/bin/` and the agent markdowns to `~/.local/share/speckit-agents/`.
4. Warns if `~/.local/bin` is not on your `PATH`.
5. Checks for `specify`. If missing and `uv` exists, offers to install it.

## Usage

Run inside the project you want to equip:

```bash
add-agents [-d DIR] [-f] <agent>...
```

| Option | Copies |
|--------|--------|
| `sdd` | `coordinator`, `planner`, `developer`, `verifier` |
| `bug-fixer` | `bug-fixer` |
| `assessor` | `idea-assessor` |

| Flag | Meaning |
|------|---------|
| `-d DIR` | Target project directory (default: current directory) |
| `-f` | Overwrite agents that already exist |
| `-h` | Show help |

### Examples

```bash
add-agents sdd                       # SDD loop agents into the current project
add-agents sdd bug-fixer assessor    # everything
add-agents -d ~/code/my-app sdd      # another directory
add-agents -f sdd                    # refresh existing agents
```

Then start Claude Code in the project and talk to the `coordinator` (e.g. `claude --agent coordinator`, or ask Claude to use it).

> `bug-fixer` and `assessor` are called by the `coordinator`. If you want the bug or assessment loops, install `sdd` too.

## How `add-agents` works

1. **Parse args.** `getopts` handles `-d`, `-f`, `-h`. At least one agent option is required.
2. **Validate.** Project dir and source dir (`~/.local/share/speckit-agents`) must exist. Unknown options fail before anything is written.
3. **Map options to files.** `sdd`, `bug-fixer`, `assessor` expand into lists of markdown files. Every source file is checked to exist.
4. **Pick destination.**
   - `<project>/.claude/` exists → `.claude/agents/`
   - else `<project>/.agents/` exists → `.agents/agents/`
   - else it warns and asks whether to create `.claude/`. Answering anything but yes aborts with nothing copied.
5. **Copy.** Existing files are skipped unless `-f`. Duplicates (an agent requested twice) are copied once.
6. **Shared rules.** Creates `<project>/AGENTS.md`, or appends the rules to an existing one between `<!-- speckit-agents:start/end -->` markers. With `-f` only that block is refreshed; the rest of the file is kept.
7. **Report.** Lists skipped files, copied files, and the destination.

## Customize

Edit the files in `agents/`, then run `./install.sh` again and `add-agents -f ...` in your projects. If you change the install path, update `AGENTS_SRC_DIR` in `add-agents` and `AGENTS_DEST_DIR` in `install.sh`. They must match, and `install.sh` checks it.
