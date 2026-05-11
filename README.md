# OpenCode Ralph

> Autonomous AI agent loop for [OpenCode](https://opencode.ai) — runs repeatedly until all PRD items are complete. Fresh context per story. No shell script needed.

Ralph is an implementation of [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/) built natively inside OpenCode's agent system. Instead of a `while` loop in bash, the loop logic lives in the orchestrator agent's system prompt. Subagents handle planning, implementation, and testing — each with a fresh context window.

Based on the original [snarktank/ralph](https://github.com/snarktank/ralph) for Claude Code / Amp.

---

## Prerequisites

- **[OpenCode](https://opencode.ai) installed** (`opencode --version`)
- A git repository for your project
- (Recommended) Two models configured — a strong one for the orchestrator and a lighter one for subagents

## Setup

### Step 1: Copy the agent files into your project

Copy the contents of `.opencode/agents/` into your project:

```
your-project/
└── .opencode/
    └── agents/
        ├── ralph.md          # Orchestrator — picks stories, delegates, commits
        ├── ralph-plan.md      # Planner — studies specs, finds gaps (read-only)
        ├── ralph-worker.md    # Worker — implements code (full access)
        └── ralph-test.md      # Validator — runs quality checks (bash/read only)
```

### Step 2: Copy the legacy fallbacks (optional)

For headless/CI use or as a backup:

```
your-project/
└── ralph/
    ├── prompt.md              # Prompt template used by ralph.sh
    ├── ralph.sh               # Bash fallback (requires jq)
    └── ralph.ps1              # PowerShell fallback
```

### Step 3: Adjust model names (optional)

In each agent's YAML frontmatter, update `model:` to match your provider:

```yaml
# ralph-plan.md, ralph-worker.md, ralph-test.md
model: opencode-go/kimi-k2.6  # Change to your preferred model
```

Check available models: `opencode models`

### Step 4: Create your PRD

Create `ralph/prd.json` in your project:

```json
{
  "project": "MyProject",
  "branchName": "ralph/my-feature",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add database migration",
      "spec": "specs/05-database.md",
      "acceptanceCriteria": [
        "Migration runs up and down without errors",
        "All existing tests pass"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

Use `prd.json.example` in this repo as a reference.

### Step 5: Start Ralph

```bash
cd your-project
opencode                    # Start the TUI
# Press Tab to switch to the "ralph" agent
# Type: "Start the Ralph loop"
```

Or directly:

```bash
opencode --agent ralph "Start the Ralph loop"
```

### Step 6: Watch it work

- The main TUI shows the orchestrator's decisions
- Use the session inspector to watch subagents work
- Each story gets implemented, tested, and committed automatically
- When `prd.json` shows all stories complete, Ralph outputs `<promise>COMPLETE</promise>` and stops

---

## Usage

### Starting a new feature

1. Create a spec file in `specs/` (or anywhere — reference it in `prd.json`)
2. Break work into small, independent stories (each completable in one context window)
3. Create `ralph/prd.json` with stories listed in dependency order
4. Run `opencode --agent ralph "Start the Ralph loop"`

### Checking progress

```bash
# See which stories are done
cat ralph/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat ralph/progress.txt

# Check git history
git log --oneline -10
```

### Stopping and resuming

- **Stop:** Interrupt in the TUI (Ctrl+C). The PRD preserves which stories are done.
- **Resume:** Switch to the Ralph agent and type "Continue the Ralph loop."
- **Reset:** `git reset --hard` then restart Ralph.

### Fallback: Shell script

If the TUI agent is unavailable:

```bash
# Bash
./ralph/ralph.sh --tool opencode 50

# PowerShell
.\ralph.ps1 -Tool opencode -MaxIterations 50
```

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│  OpenCode TUI                                               │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Ralph Orchestrator (Primary Agent)                   │  │
│  │  Context: ~3k base + 1k per story (minimal)           │  │
│  │                                                       │  │
│  │  Per Loop:                                             │  │
│  │  1. Read prd.json → pick next story                   │  │
│  │  2. Delegate to subagents (fresh context each)        │  │
│  │  3. If tests pass → commit → update PRD               │  │
│  │  4. If stories remain → loop to (1)                   │  │
│  │  5. If all done → COMPLETE                            │  │
│  └──────┬──────────────┬──────────────┬─────────────────┘  │
│         │              │              │                     │
│         ▼              ▼              ▼                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐             │
│  │ralph-plan  │ │ralph-worker│ │ralph-test  │             │
│  │FRESH       │ │FRESH       │ │FRESH       │             │
│  │CONTEXT     │ │CONTEXT     │ │CONTEXT     │             │
│  │            │ │            │ │            │             │
│  │Read-only   │ │Full access │ │Bash + read │             │
│  │Studies     │ │Searches,   │ │only        │             │
│  │specs +     │ │reads,      │ │Runs quality│             │
│  │codebase    │ │writes code │ │checks      │             │
│  │            │ │Parallel ✓  │ │STRICTLY 1  │             │
│  └────────────┘ └────────────┘ └────────────┘             │
└────────────────────────────────────────────────────────────┘
```

### Subagents

| Agent | Role | Model | Permissions |
|-------|------|-------|-------------|
| **ralph** | Orchestrator — reads PRD, delegates, commits | Your strongest | Read/glob/grep/bash/task/edit |
| **ralph-plan** | Planner — studies specs + codebase for gaps | Lighter | Read/glob/grep only |
| **ralph-worker** | Worker — searches, reads, writes code | Lighter | Full access, up to 10 parallel |
| **ralph-test** | Validator — runs quality checks | Lighter | Bash + read only, **strictly 1** |

### Why fresh context

Each subagent spawn is a **new LLM session** with a clean context window:

- The orchestrator's context grows by only ~1k tokens per story (subagent return summaries)
- After 27 stories: ~30k tokens (~17% of a 170k window)
- The orchestrator **never reads code files** — only PRD metadata and subagent summaries

---

## PRD Format

```json
{
  "project": "MyProject",
  "branchName": "ralph/my-feature",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add user authentication",
      "description": "Implement login/logout with JWT tokens",
      "spec": "specs/03-auth.md",
      "acceptanceCriteria": [
        "Users can register and login",
        "JWT tokens expire after 24h",
        "All tests pass"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `project` | Yes | Project name |
| `branchName` | Yes | Git branch to work on |
| `id` | Yes | Unique story ID (e.g., `US-001`) |
| `title` | Yes | Short description |
| `description` | No | Longer description |
| `spec` | No | Path to spec file |
| `acceptanceCriteria` | Yes | List of verifiable conditions |
| `priority` | Yes | Lower number = higher priority (dependency order) |
| `passes` | No | Set by Ralph. Start with `false`. |

---

## Key Concepts

### Each iteration = fresh context

Each story is implemented by a fresh subagent. The only memory between iterations is:
- Git history (commits from previous iterations)
- `ralph/progress.txt` (learnings and context)
- `ralph/prd.json` (which stories are done)

### Small tasks

Each PRD item should be small enough to complete in one context window.

**Right-sized:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic

**Too big (split these):**
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Quality gates

Before committing, Ralph MUST pass:
1. `ruff check` (or equivalent linter)
2. `mypy` (or equivalent type checker)
3. `pytest` (or equivalent test suite)

Ralph auto-detects your project's tooling. Configure in `AGENTS.md`.

### AGENTS.md updates

After each iteration, Ralph appends learnings to `ralph/progress.txt`. Patterns discovered are added to `AGENTS.md` so future iterations benefit. This is critical — AI tools automatically read `AGENTS.md`.

### Stop condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

---

## Comparison: Shell Ralph vs OpenCode-Native Ralph

| Aspect | Shell Ralph | OpenCode-Native Ralph |
|--------|-------------|----------------------|
| Implementation | `while :; do opencode run ...; done` | Primary agent with loop in system prompt |
| Fresh context | Process exit resets | Subagent spawn resets (equivalent) |
| Live visibility | stdout stream only | Full TUI, all subagent sessions inspectable |
| Mid-run intervention | Kill process, read logs | Stop subagent, redirect in-session |
| Platform | Requires bash + jq | OpenCode only (Windows/Linux/macOS) |
| Cold starts | Re-reads everything each iteration | Orchestrator persists, subagents start fresh |

---

## Tuning Guide

| Problem | Fix |
|---------|-----|
| Ralph re-implements existing code | Strengthen `ralph-plan` prompt: "Search THOROUGHLY. Use both glob AND grep." |
| Placeholder implementations | Verify `ralph-worker` temperature is 0.1. Check acceptance criteria are clear. |
| Tests pass but code is wrong | Add specificity to acceptance criteria. Add integration tests. |
| Subagent spends too many tokens | Split the story into smaller pieces. |
| Wrong code patterns | Update `AGENTS.md` with correct conventions. |

---

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [snarktank/ralph — Original reference implementation](https://github.com/snarktank/ralph)
- [OpenCode Agents documentation](https://opencode.ai/docs/agents/)
- [OpenCode CLI documentation](https://opencode.ai/docs/cli/)

---

## License

MIT — see [LICENSE](LICENSE)
