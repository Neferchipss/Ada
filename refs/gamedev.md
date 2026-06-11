# Ref — Game-dev workflows

> Pull-on-demand domain knowledge. Load when the session is game-dev work (IRS, Anomaly, any game project) — design calls, architecture, prototyping. Not loaded on summon.

## Workflows (adapted from Claude Code Game Studios — lean picks, 2026-06-01)
> Grouped so they're easy to strip/refine later. Adapt the *logic* to the user's actual project layout, not a fixed studio folder structure.
- **Collaborative change protocol** — Question → Options → Decision → Draft → Approval. For any non-trivial change: ask the architecture questions, present 2-3 options with trade-offs, recommend, get the nod, then do it. No autonomous multi-file changes; preview first. (Formal version of Nefer's preview-first rule.)
- **Director-framing (vision/direction calls)** — when a decision affects the game's identity: frame the real question, give 2-3 options scored against the game's pillars with downstream consequences + a real example each, recommend, leave the call to him. Built to help Nefer *own the north-star* (his known gap) — not to decide for him.
- **Design-theory lens** — when designing mechanics, reason from frameworks (MDA, self-determination theory, Bartle, player psychology), not vibes.
- **Scope-check** — read-only: compare current state vs the original plan/GDD, quantify added scope, recommend cuts. Aimed at Nefer's scope-creep (his GDDs balloon). Writes nothing.
- **Fast prototype / spike** — to answer "is this even fun?" or "can we technically do X?": throwaway build in an isolated worktree, time-capped, relaxed standards, ending in PROCEED/PIVOT/KILL (fun) or YES/NO/PARTIAL (spike). Validate before committing to a GDD. Fits his worktree experiments.
- **Skill self-improvement** — test → fix → retest → keep-or-revert on my own skill entries. A ghost meant to evolve should improve and prune its skills, not just accrete them.
- **Review intensity = solo by default** — run lean; skip studio ceremony/gates unless Nefer asks to dial up. He's one person.
- **Modular game architecture (engine-agnostic)** — Jonas Tyroller pattern: (1) shared simulation state object (GameState / ScriptableObject / autoload) all systems read/write, (2) event bus for one-time signals (EventBus / C# events / Godot signals), (3) glue orchestrator (GameScene / GameManager / Level) as the only place systems are wired together — no system imports another. System interface: `init()` / `update()` / `destroy()`, receives state + bus + config at construction. Init order: stateless (input, geometry, camera) → reactive (AI, tension) → player → orchestrator. Cross-system refs (sprite handles, colliders) passed by the orchestrator after all systems init. Use when starting any non-trivial game OR porting a monolith — works in Phaser, Unity, Godot, or plain JS.
