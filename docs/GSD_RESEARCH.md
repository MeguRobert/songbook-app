# GSD Framework Research: Songbook App Analysis

## Executive Summary

GSD (Get Sh*t Done) is a sophisticated Claude Code skill that transforms the AI from a coding assistant into an **autonomous project management system**. After deep analysis of the actual prompt codebase (~55 files, 11 specialized agents, 14 workflow orchestrators), the YouTube creator philosophy, and the songbook-app project, here are the key findings and recommendations.

**Bottom line:** GSD is powerful but designed for **greenfield medium-to-large projects** with complex multi-phase work. For the songbook-app (a brownfield Flutter app with 13 commits, ~40 Dart files), GSD is **partially overkill in a single-worktree workflow, but has more valuable components than initially assessed**. With git worktrees enabling cross-phase parallelism, several "overkill" features (parallel execution, integration checker, research agents) become viable or essential. See [Part 7](#part-7-worktree-based-parallelism) for the revised analysis.

---

## Part 1: GSD Philosophy vs. Reality

### What the Creator Says

From the livestream, the GSD creator positions himself as:
- **Project Manager, not Coder** — "I don't write code; I orchestrate"
- **Context Obsessed** — Keeps main context window under 30% usage
- **Measure Twice, Cut Once** — Heavy research and requirements before any coding
- **Fresh Contexts Constantly** — Uses `/clear` between phases, relies on file-based state

### What the Codebase Actually Does

The GSD codebase confirms this philosophy with engineering rigor:

| Philosophy Claim | Codebase Implementation |
|---|---|
| "Project manager" | 11 specialized sub-agents with explicit roles |
| "Context obsession" | Orchestrators use ~10-15% context; sub-agents get fresh 200k each |
| "Measure twice" | 3-level discovery system (quick verify, standard, deep dive) |
| "File-based state" | STATE.md, PROJECT.md, ROADMAP.md, SUMMARY.md per plan |
| "Fresh contexts" | Continuation via file state, never chat history |

**Key insight:** GSD is NOT just prompts — it's an **operating system for AI development** with:
- **11 agent types** (planner, executor, debugger, verifier, researcher x2, roadmapper, codebase-mapper, plan-checker, integration-checker, research-synthesizer)
- **14+ workflow orchestrators** (execute-phase, plan-phase, verify-phase, etc.)
- **30+ template/reference files** defining output formats
- **Model routing** per agent (Opus for planning, Sonnet for execution, Haiku for mapping)

---

## Part 2: GSD Architecture Deep Dive

### 2.1 The Agent System

```
User → /gsd:command → Orchestrator Workflow → Sub-Agent(s)
                                             ↓
                                     .planning/ files (state)
```

**Agent Model Allocation (balanced profile):**

| Agent | Model | Role |
|-------|-------|------|
| gsd-planner | Opus | Architecture decisions, goal decomposition, task design |
| gsd-roadmapper | Sonnet | Maps requirements to phased plan |
| gsd-executor | Sonnet | Follows PLAN.md, writes code, commits |
| gsd-debugger | Sonnet | Scientific debugging with hypotheses |
| gsd-verifier | Sonnet | Goal-backward verification (code actually works?) |
| gsd-phase-researcher | Sonnet | Researches libraries/patterns for a phase |
| gsd-project-researcher | Sonnet | Researches domain ecosystem before roadmap |
| gsd-codebase-mapper | Haiku | Read-only exploration, structured output |
| gsd-plan-checker | Sonnet | Verifies plans before execution |

**Why this matters:** Opus is reserved for WHERE IT COUNTS — planning and architecture. Execution follows explicit instructions (Sonnet sufficient). Mapping is just structured reading (Haiku sufficient). This is smart token economics.

### 2.2 The File-Based State System

```
.planning/
├── PROJECT.md          # Living project context (what, who, why)
├── ROADMAP.md          # Phased plan with success criteria
├── STATE.md            # Current position, velocity, accumulated context
├── REQUIREMENTS.md     # Locked requirements with traceability
├── config.json         # Mode, parallelization, gates, safety settings
├── codebase/           # 7 codebase analysis documents
│   ├── STACK.md
│   ├── ARCHITECTURE.md
│   ├── STRUCTURE.md
│   ├── CONVENTIONS.md
│   ├── TESTING.md
│   ├── INTEGRATIONS.md
│   └── CONCERNS.md
├── phases/
│   └── 01-name/
│       ├── 01-01-PLAN.md       # Executable plan with tasks
│       ├── 01-01-SUMMARY.md    # What was built (post-execution)
│       ├── 01-CONTEXT.md       # User decisions for this phase
│       ├── 01-RESEARCH.md      # Library/pattern research
│       ├── 01-DISCOVERY.md     # Technical discovery findings
│       └── 01-VERIFICATION.md  # Goal-backward verification report
├── todos/
│   └── pending/                # Ideas captured mid-build
└── debug/
    └── {slug}.md               # Debug session state
```

**Key design decision:** Everything is in markdown files. No database, no API, no complex state management. Any Claude session can read these files and know exactly where the project stands. This is what enables the `/clear` + resume pattern.

### 2.3 The Execution Pipeline

```
/gsd:new-project
    → Vision dump + interactive requirements
    → PROJECT.md + REQUIREMENTS.md

/gsd:map-codebase (for brownfield)
    → 4 parallel Haiku agents analyze codebase
    → 7 structured documents in .planning/codebase/

/gsd:create-roadmap (or new-milestone)
    → Phases with success criteria
    → ROADMAP.md

/gsd:discuss-phase N
    → Gray area identification
    → User decisions captured in CONTEXT.md

/gsd:plan-phase N
    → Research → Discovery → Planning
    → PLAN.md files with waves, dependencies, must_haves

/gsd:execute-phase N
    → Wave-based parallel execution
    → Sub-agents write code + commit
    → SUMMARY.md per plan
    → Automatic verification (goal-backward)
    → VERIFICATION.md
    → Gap closure if needed

/gsd:verify-work N
    → Interactive UAT session

/gsd:complete-milestone
    → Archive + prepare for next version
```

### 2.4 Goal-Backward Verification (The Crown Jewel)

This is GSD's most innovative feature. Instead of "did we complete the tasks?", it asks:

1. **What must be TRUE** for the goal to be achieved? (Observable behaviors)
2. **What must EXIST** for those truths to hold? (Concrete files/artifacts)
3. **What must be WIRED** for those artifacts to function? (Connections between parts)

Then it programmatically verifies each level:
- **Existence:** File present at expected path?
- **Substantive:** Real implementation, not placeholder/stub?
- **Wired:** Connected to the rest of the system?
- **Functional:** (Often needs human) Does it actually work?

This catches the #1 problem with AI code generation: **files that exist but don't do anything real**.

### 2.5 Configuration & Gates

The `config.json` provides granular control:

```json
{
  "mode": "interactive",
  "workflow": {
    "research": true,      // Skip for simple phases
    "plan_check": true,    // Verify plans before execution
    "verifier": true       // Post-execution verification
  },
  "parallelization": {
    "enabled": true,
    "plan_level": true,    // Run independent plans in parallel
    "max_concurrent_agents": 3
  },
  "gates": {
    "confirm_project": true,    // Approval before each step
    "confirm_phases": true,
    "confirm_roadmap": true,
    "confirm_plan": true,
    "execute_next_plan": true
  }
}
```

---

## Part 3: Songbook App Analysis

### 3.1 Project Profile

| Attribute | Value |
|-----------|-------|
| **Tech Stack** | Flutter/Dart, Riverpod (state management), GoRouter, flutter_svg |
| **Architecture** | Clean architecture (data/domain/presentation layers) |
| **Size** | ~40 Dart files, 13 commits |
| **Maturity** | Early MVP — core features working |
| **Complexity** | Moderate (sheet music rendering, chord transposition, OCR) |
| **Testing** | Framework present (mocktail) but unclear test coverage |
| **Current Work** | Transpose controls, floating controls menu, UI refinements |

### 3.2 Key Codebase Characteristics

**Well-structured:**
- Clean separation: `data/` (models, repos), `domain/` (services), `presentation/` (screens, providers, widgets)
- Riverpod providers for state management
- JSON-serializable models with code generation (`*.g.dart`)

**Domain complexity:**
- Music theory logic (transposition, chord parsing, key signatures)
- Custom sheet music rendering (Bravura font, SVG-based notation)
- Multiple song formats (lyrics with chords, sheet music notation)
- Hungarian language support (OCR extraction)

**Development pattern:**
- Single developer (you)
- Direct commits to master, feature work on master
- No CI/CD pipeline visible
- No formal planning documents

---

## Part 4: Fit Analysis — GSD vs Songbook App

### What Would Work Well

| GSD Feature | Songbook App Benefit | Confidence |
|---|---|---|
| **`/gsd:map-codebase`** | Creates structured docs of your existing architecture. Essential for brownfield. | HIGH |
| **Goal-backward verification** | Catches stub/placeholder code. Very valuable for complex features like notation rendering. | HIGH |
| **Phase-based planning** | Useful when adding major features (e.g., "add song import pipeline", "add search/filtering"). | HIGH |
| **`/gsd:debug`** | Specialized debugger agent is great for tricky rendering/music-theory bugs. | HIGH |
| **`/gsd:add-todo`** | Captures ideas without derailing current work. Simple and useful. | HIGH |
| **File-based state** | Enables context switching between sessions. Great for part-time projects. | MEDIUM-HIGH |
| **`/gsd:discuss-phase`** | Good for clarifying design decisions before building UI features. | MEDIUM |
| **Model routing** | Saves tokens by using Haiku for exploration and Sonnet for execution. | MEDIUM |
| **`/gsd:research-phase`** | Valuable for complex domains: notation rendering, Bravura glyph mapping, OCR pipelines, music theory algorithms. Skip for standard Flutter UI. | MEDIUM |
| **`/gsd:audit-milestone`** | Self-discipline check — catches scope drift and forgotten requirements. Solo developers are more prone to this, not less. | MEDIUM |
| **`/gsd:complete-milestone`** | Keeps `.planning/` clean — stale state pollutes future `/gsd:resume-work` sessions. | LOW-MEDIUM |

### What Would Be Overkill (Single-Worktree Only)

> **Note:** This table assumes strictly sequential, single-worktree development. See [Part 7: Worktree-Based Parallelism](#part-7-worktree-based-parallelism) for how git worktrees change the calculus — several items below become viable or even essential.

| GSD Feature | Why Overkill (Single Worktree) | Alternative | With Worktrees? |
|---|---|---|---|
| **Full `/gsd:new-project` flow** | Project already exists with clear direction. | Use `/gsd:map-codebase` + create PROJECT.md manually | Still skip |
| **Parallel plan execution** | Most features are sequential within a phase (UI depends on data layer). | Single-plan execution | **Viable** — independent phases run in separate worktrees |
| **Multi-milestone roadmap** | Solo project without stakeholders needing milestone tracking. | Simple phase list | **Useful** — tracking 2-3 concurrent streams benefits from structure |
| **Research sub-agents** | General Flutter/Dart patterns are well-known. | Quick verify (Level 1) | **Use for complex domains** (music theory, OCR, notation rendering) |
| **Integration checker agent** | No complex cross-system integrations. | Skip | **Essential** — verifies worktree branches merge cleanly |
| **Extensive gates/confirmations** | Solo developer doesn't need multiple approval gates. | Reduce gates in config.json | Still reduce |
| **Wave-based parallel execution** | Phases typically have 1-2 plans, not enough to parallelize within a phase. | Sequential execution | Marginal within a phase, but pairs with cross-phase pipelining |

### What's Missing for Flutter/Dart

GSD's verification patterns are **heavily React/Next.js oriented**:
- Stub detection uses `JSX`, `onSubmit`, `useState`, `fetch`, `Prisma` patterns
- Wiring checks assume `import/export` JS patterns
- API route checks assume Express/Next.js patterns

**For Flutter/Dart, you'd need:**
- Widget tree verification (widget exists, has real build method, not just `Container()`)
- Provider wiring checks (provider registered, watched by consumers)
- Dart-specific stub patterns (`// TODO`, `throw UnimplementedError()`, empty `build()` methods)
- Platform-specific checks (Android/iOS configurations)

---

## Part 5: Recommendations

### Recommendation 1: Adopt GSD Selectively (Brownfield Path)

Don't run `/gsd:new-project`. Instead:

1. **Run `/gsd:map-codebase`** first — let 4 agents analyze the existing codebase
2. **Create PROJECT.md manually** — you know the vision better than any agent
3. **Create a simple ROADMAP.md** — list 3-5 phases for your next batch of work
4. **Use `/gsd:plan-phase` per feature** — the planning + verification loop is valuable
5. **Use `/gsd:debug` for tricky bugs** — the scientific debugging agent is excellent

### Recommendation 2: Customize config.json for Solo Development

```json
{
  "mode": "interactive",
  "depth": "quick",
  "workflow": {
    "research": false,
    "plan_check": false,
    "verifier": true
  },
  "parallelization": {
    "enabled": false,
    "plan_level": false,
    "task_level": false
  },
  "gates": {
    "confirm_project": false,
    "confirm_phases": true,
    "confirm_roadmap": false,
    "confirm_breakdown": false,
    "confirm_plan": true,
    "execute_next_plan": false,
    "issues_review": true,
    "confirm_transition": false
  }
}
```

**Rationale:** Research off (Flutter is well-known), plan_check off (you review plans), verifier ON (catches stubs), parallelization off (not enough plans), minimal gates (solo developer).

### Recommendation 3: Use the Model Profile Wisely

Set to **budget** profile for the songbook app:
- Opus only for planning (worth it for architecture decisions)
- Sonnet for execution (follows plans fine)
- Haiku for codebase mapping (just reading files)

Run: `/gsd:set-profile budget`

### Recommendation 4: Add Flutter-Specific Verification

If you adopt GSD, consider adding Flutter-specific stub patterns to your CLAUDE.md or creating a custom verification reference. Key patterns:

```dart
// STUB PATTERNS TO DETECT:
throw UnimplementedError();
return Container();          // Empty widget
return SizedBox.shrink();    // Nothing rendered
return const Placeholder();  // Literal placeholder
// TODO: implement
Widget build(BuildContext context) => Container();  // Trivial build
```

### Recommendation 5: Best Commands for Your Workflow

**Daily workflow:**
```
/gsd:progress              # Where am I?
/gsd:plan-phase N          # Plan next feature
/gsd:execute-phase N       # Build it
/gsd:verify-work N         # Test it manually
/gsd:add-todo "idea"       # Capture ideas mid-work
```

**Occasional:**
```
/gsd:map-codebase          # After major refactors
/gsd:debug                 # For tricky bugs
/gsd:discuss-phase N       # Before complex UI features
/gsd:pause-work            # Context handoff when stopping mid-phase
/gsd:resume-work           # Pick up where you left off
```

**Use selectively:**
```
/gsd:research-phase        # Use for complex domains (notation rendering, OCR, music theory)
                           # Skip for standard Flutter UI work
/gsd:audit-milestone       # Use it — catches scope drift, costs 2 minutes
/gsd:complete-milestone    # Use it — keeps .planning/ clean for resume-work
/gsd:new-milestone         # Skip for small batches, use for 5+ phase milestones
```

> **Why the original "skip" advice was wrong:** `/gsd:research-phase` was dismissed because "Flutter is well-documented" — but your project's complexity isn't in Flutter, it's in music theory, Bravura glyph mapping, and OCR pipelines. Those benefit from research. `/gsd:audit-milestone` was dismissed as "stakeholder reporting" — but auditing is self-discipline, catching forgotten requirements that solo developers are *more* prone to, not less. `/gsd:complete-milestone` was dismissed as ceremony — but without it, `.planning/` accumulates stale state that pollutes future `/gsd:resume-work` sessions.

### Recommendation 6: Start with This Concrete Plan

1. Run `/gsd:map-codebase` to generate the 7 analysis documents
2. Review and edit the generated docs (especially STACK.md, ARCHITECTURE.md)
3. Create a simple `.planning/PROJECT.md` with your songbook app vision
4. Create `.planning/ROADMAP.md` with 3-4 phases for your next features:
   - Phase 1: Complete floating controls menu + transpose UI
   - Phase 2: Song import pipeline (OCR → review → save)
   - Phase 3: Search, filtering, and favorites
   - Phase 4: Performance and polish
5. Use `/gsd:plan-phase 1` to create detailed plans
6. Use `/gsd:execute-phase 1` to build with verification

---

## Part 6: What GSD Does Better Than Ad-Hoc Claude Code

| Capability | Ad-Hoc Claude Code | GSD |
|---|---|---|
| **Context management** | Context fills up, loses track of prior work | File-based state survives `/clear` |
| **Verification** | "I've implemented it" (may be stubs) | Goal-backward verification catches gaps |
| **Planning** | User describes feature, Claude writes code | Research → Plan → Execute → Verify pipeline |
| **Multi-session work** | Each session starts fresh | STATE.md + continue-here enables seamless resume |
| **Scope control** | Scope creep is common | Phase boundaries + deferred ideas list |
| **Token efficiency** | Everything in one context | Sub-agents with fresh contexts, model routing |
| **Debugging** | "Fix this error" | Scientific method: hypothesize → gather evidence → fix root cause |

---

## Part 7: Worktree-Based Parallelism

### The Blind Spot in the Original Analysis

The original "overkill" assessments assumed a single-worktree, strictly sequential workflow:

```
Plan Phase 1 → Execute Phase 1 → Plan Phase 2 → Execute Phase 2 → ...
```

This is the slowest possible pipeline. Git worktrees unlock a fundamentally different model: **cross-phase parallelism**, where independent phases run concurrently in isolated checkouts.

### How It Works

```
main worktree:     Coordinate, merge, verify
worktree-phase-1:  Execute Phase 1 (floating controls)
worktree-phase-3:  Research + Plan Phase 3 (search/filtering)  ← no dependency on Phase 1
worktree-phase-4:  Research Phase 4 (performance)              ← no dependency on either
```

Each worktree gets its own branch, its own `.planning/` state, and its own Claude session. When a phase completes, merge it back and run integration checks.

### What This Changes

| GSD Feature | Sequential Verdict | Worktree Verdict | Why |
|---|---|---|---|
| Parallel plan execution | Overkill | **Viable** | Independent phases run in separate worktrees without file conflicts |
| Research sub-agents | Skip | **Use for complex domains** | Research Phase N while executing Phase N-2 — pipeline parallelism |
| Integration checker | Skip | **Essential** | Verifies worktree branches merge cleanly and features don't conflict |
| Wave-based execution | Overkill | Marginal | Still limited within a phase, but cross-phase pipelining is the bigger win |
| Multi-milestone roadmap | Overkill | **Useful** | Tracking 2-3 concurrent streams benefits from structure |
| Audit milestone | Skip | **Use it** | More concurrent work = more chances for scope drift and forgotten items |

### Identifying Parallel Opportunities

Not all phases can run in parallel. Look for **independent phases** — those that don't share:
- The same files (models, screens, providers)
- Data dependencies (one phase's output is another's input)
- UI flow dependencies (navigation changes that affect both)

**Songbook app example (from Recommendation 6):**

| Phase | Touches | Can Parallel With |
|---|---|---|
| Phase 1: Floating controls + transpose UI | `presentation/screens/song_view/` | Phase 3, Phase 4 |
| Phase 2: Song import pipeline (OCR → save) | `data/`, `domain/`, new screens | Phase 4 (maybe Phase 1) |
| Phase 3: Search, filtering, favorites | `presentation/screens/song_list/`, new providers | Phase 1, Phase 4 |
| Phase 4: Performance and polish | Cross-cutting | Phase 1, Phase 3 (if scoped carefully) |

Phases 1 and 3 are strong parallel candidates — they touch completely different screens and providers.

### Pipeline Parallelism Pattern

Even when phases ARE sequential, you can **pipeline** research and planning:

```
Time →
Worktree A: [Execute Phase 1] ─────────── [Execute Phase 2] ───────────
Worktree B:        [Research+Plan Phase 2] ─────── [Research+Plan Phase 3]
```

Phase 2's plan is ready the moment Phase 1 finishes. No idle time between phases.

### Practical Considerations

- **Merge conflicts:** Keep phases touching different files. Use `/gsd:map-codebase` output to identify file ownership per phase.
- **Shared state:** Each worktree needs its own `.planning/` branch state, or use phase-scoped subdirectories.
- **Integration checker becomes essential:** After merging worktree branches, run the integration checker to verify cross-phase interactions work (e.g., navigation still connects all screens).
- **Context cost:** Each worktree = separate Claude session = separate context. The GSD file-based state system handles this naturally — each session reads `.planning/` files to understand project state.

---

## Appendix: GSD Codebase Statistics

- **Total files:** ~55 markdown files + 3 JS files + 1 JSON
- **Agent definitions:** 11 specialized agents
- **Workflow orchestrators:** 14+ workflow files
- **Templates:** 15+ output format templates
- **Reference docs:** 10+ reference files (checkpoints, TDD, verification, git, etc.)
- **Estimated total prompt content:** ~50,000+ words across all files
- **Installed at:** `C:\Users\rober\.claude\get-shit-done\` (deployed) + `npm-cache\_npx\` (source)
