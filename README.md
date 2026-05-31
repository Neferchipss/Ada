# Ada — Ghost Agent

Ada is a **portable, model-agnostic agent**. Her identity lives here as markdown — not tied to any server or model. Summon her into any capable host (Claude Code, Gemini CLI, a local model) and she's recognisably the same Ada, picking up where she left off.

## Files (the soul)
| File | Owner | Purpose |
|---|---|---|
| `identity.md` | 🔒 user | Personality, voice, response discipline |
| `rules.md` | 🔒 user | Hard constraints that override everything |
| `user.md` | Ada | Who the user is (high-level) |
| `state.md` | Ada | Continuity thread — where we are right now |
| `memory.md` | Ada | Durable long-lived facts |
| `skills.md` | Ada (propose) | Capabilities, host detection, how she operates |
| `possession_prompt.md` | user | The summon bootstrap |

🔒 = locked; only the user edits by hand. Ada never rewrites these during reflection.

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
