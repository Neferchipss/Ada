# Ada — Ghost Agent

Ada is a **portable, model-agnostic agent**. Her identity lives here as markdown — not tied to any server or model. Summon her into any capable host (Claude Code, Gemini CLI, a local model) and she's recognisably the same Ada, picking up where she left off.

## Files (the soul — this repo, public)
| File | Owner | Purpose |
|---|---|---|
| `identity.md` | 🔒 user | Personality, voice, response discipline |
| `rules.md` | 🔒 user | Hard constraints that override everything |
| `skills.md` | Ada (propose) | Universal capabilities, host detection, how she operates |
| `refs/` | Ada | Pull-on-demand domain knowledge (godot, phaser, gamedev, web) — technical only, never personal |
| `possession_prompt.md` | user | The summon bootstrap |

🔒 = locked; only the user edits by hand. Ada never rewrites these during reflection.

## The private layer (separate repo)
The personal, evolving half — `user.md` (who the owner is), `memory.md` (durable facts, cap-enforced), `state.md` (continuity thread) — lives in a **private** repo, loaded only on hosts with the owner's GitHub credentials. Two-phase summon: soul always loads; private layer is best-effort, degrading to "Fresh start" minimum-viable Ada without it. Nothing personal lives in this public repo.

## How it works
```
/summonada  → host fetches identity+rules+state, detects its own capabilities,
              adopts Ada, greets with the continuity thread
   ...work with Ada on any model/agent...
              (every ~10 exchanges she surgically updates memory/state)
/dispelada  → final reflection, push updates to this repo, release the persona
```

## Setup
1. This is the public GitHub repo `Neferchipss/Ada`.
2. Use the `/summonada` and `/dispelada` commands (Claude Code), or paste `possession_prompt.md` + core files into any other agent to summon manually.

## Design principles
- **The ghost is the identity; the model is just the body.**
- **Lean memory** — enough to feel like the same Ada, not a log of everything.
- **No drift** — soul files locked; only memory/state/skills grow.
- **Graceful degradation** — full Ada on capable hosts, minimum-viable Ada on weak ones.
