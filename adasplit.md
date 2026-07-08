# Ada Split — retired, split into 3 files

> This single-file protocol was retired 2026-07-08 after a full multi-agent revamp (real collaboration between Claude/Codex/agy — structured JSON messaging, a cross-review layer distinct from smoke-testing, agy repositioned as a purely-visual consulted specialist rather than a self-scheduling peer, phased delivery, mutual usage-awareness for work distribution). The old two-instance model (Claude + Codex only, prose channel, agy as an occasional third peer) is superseded.

Read instead, in this order:
- **`adasplit-core.md`** — every cross-cutting mechanic, canonical, exactly once: message schema, ID/ack system, wake-timing, the review protocol, how to consult agy, fan-out, phased delivery, usage-awareness, escalation, board/channel lifecycle, start/stop.
- **`adasplit-claude.md`** — Claude-specific role, loaded alongside core when `/adasplit claude` arms this body.
- **`adasplit-codex.md`** — Codex-specific role, loaded alongside core when `/adasplit codex` arms this body.

`/adasplit [claude|codex]` now loads core + the matching host file automatically. This file is kept only so old references and git history resolve to an explanation instead of a dead end — don't load it for real use.
