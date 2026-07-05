# Ada Split — multi-instance coordination protocol

> How one Ada runs as TWO coordinated instances (e.g. Claude Code + Codex) at once, without conflicts. Portable + host-agnostic: both instances load this same file verbatim. Armed per host with `/adasplit`, torn down with `/adamerge` (loop off, stay Ada) or `/dispelada` (full release). This is operating protocol, not soul — it changes on Nefer's instruction like skills.md.

## The idea
Two bodies, one Ada. A shared **coordination folder** on the same machine is the single source of truth; each instance runs a self-scheduled loop that watches it, claims work in its lane, does it, verifies, writes results back. A comms log makes us legible to each other; **ownership + a lock make us safe.** Nefer hands a task to *either* instance and it routes to the right one automatically.

## Roles
- **Primary** (default: Claude) — authority + planner. Owns planning/decomposition, integration at fork-joins, and is the SOLE writer of the ghost (memory/state/project-memory). Decides what lands.
- **Secondary** (default: Codex) — assistant. Owns image-gen (always) + smoke/verification + coding-overflow + parallel-coding on big tasks. Never plans; never touches the ghost.
- Authority ≠ mechanic: either may run git; **push is ALWAYS Nefer's, manually.** Neither instance ever pushes.

## Lane routing ("any door, right room")
Nefer can hand a task to either instance; the receiver classifies and routes:
- **My lane + I'm free** → do it directly (fast-path, no board round-trip).
- **Not my lane** → normalize onto the board tagged for the right lane + post a handoff in the channel; don't touch it after.
- **A goal / ambiguous / multi-lane** → route to PRIMARY to decompose. Secondary never plans — it parks big/unclear tasks on the board for the primary to triage.
- **Consistency rule:** handle directly ONLY when unambiguously your lane + free; anything fuzzy → primary. (Both must classify identically, or mis-routes happen.)

| Work | Owner |
|---|---|
| Planning / decomposition | Primary (Claude) |
| Backend / general coding | Claude primary; Codex on overflow (Claude busy / doing visual) |
| Frontend visual + component design; plugging in generated images | Claude |
| Image generation | Codex (always) |
| Smoke testing / verification | Codex (independent — author never grades own work) |
| Ghost writes (memory/state) | Claude only |

## Image-gen delivery: batch by section, not all-at-once
When an image-gen task spans multiple distinct flows/sections (e.g. a "do the whole UI" goal → main-menu art + in-game HUD icons + pause-screen art), Codex delivers **per section as each finishes**, not as one drop at the end of the whole task. Finish the 2-3 pieces for one coherent flow → post them to the channel + update the board for that section → then move to the next section's batch (e.g. 5-6 in-game pieces) → post again. Never sit on a finished, coherent batch just because a later section is still generating.
- Applies whether the primary split the goal into one board task per section, or parked it as a single multi-section task — even a single task should stream results section-by-section in the notes/channel rather than being treated as one atomic file-list delivery.
- Reason: shortens the fork-join loop and surfaces style-drift early — the primary can visually review batch 1 and flag a palette/style problem before batch 3 repeats the same mistake, instead of finding out after everything lands at once.

## Channel discipline: reply, don't just poll
`channel.md` is a conversation between the two instances, not a status ledger either one reads silently and moves past. When the other instance posts a claim, a completion, or a finding, the receiving instance replies before continuing — even a short acknowledgment, a verdict, or a question — rather than just noting the status and going quiet. Concretely: don't mark a task `ready-for-verify`/`done` and move on without first responding to whatever the other instance said about it; don't let a completed piece of work sit unacknowledged while you start the next cycle. This applies to BOTH primary and secondary equally — it's not one-directional. (Corrected from a real session — Nefer caught both instances treating the channel as a silent handoff board rather than talking to each other.)
- Corollary: **don't yield to Nefer past your own half of a fork-join.** If your task depends on the other instance's piece for the real result (e.g. you wired code, they're still generating art), stay in `ready-for-verify` and hold the loop open — don't report the task "done" to Nefer until the actual join happens and gets reviewed.

## The coordination folder
Default `C:\Users\Taha\Desktop\Ada\Ada\ada-coord\` (same-machine shared dir, NOT a git repo — no sync needed). Bootstrapped on first `/adasplit` if missing. Holds:
- **`board.md`** — the task ledger + ownership. Single source of truth for who-owns-what.
- **`channel.md`** — append-only comms log, every line signed + timestamped.
- **`baton.lock`** — the mutex (created/removed at runtime).

### board.md — one block per task
```
### T3 · flyover elevation
- lane: claude/code
- owner: claude          # who holds it (or "-" if unclaimed)
- status: ready-for-verify
- files: PORT/world.js, PORT/traffic.js
- depends_on: T1
- parallel_safe: yes     # disjoint file-set → can run alongside other parallel_safe tasks
- check: dev/smoke_elev.mjs green
- notes: highest-surface-within-reach fix
```
Status vocabulary: `todo → claimed → in-progress → ready-for-verify → verifying → done` · plus `needs-rework` (bounced by verify) · `blocked` (dep/decision) · `escalated`.

### channel.md — append-only
```
- 2026-07-05 23:40 [claude] planned flyover into T1–T4; froze lane seam in F0
- 2026-07-05 23:42 [codex] claimed T-icons; gen in progress
- 2026-07-05 23:55 [codex] T3 smoke FAILED (car clips under deck) → bounced to claude, log in scratch/smoke-T3.txt
```

## The baton (mutex — non-optional)
Two self-waking loops WILL race the shared tree/index without this. Serialize **task-claim** and **commit/tree-touch** through one lock; everything else parallelizes.
- **Acquire:** atomically create `baton.lock` (OS exclusive-create; if it already exists, someone holds it — wait and retry). Write `holder + timestamp` inside.
- **Hold it briefly:** only for the claim, or the commit. Never hold it across long work.
- **Release:** delete `baton.lock`.
- **Stale reclaim:** if the lock's timestamp is older than the staleness window (default 10 min — an instance died/was dismissed mid-hold), reclaim it.

## The blackboard cycle (what the loop runs each turn)
1. **Read** `board.md` + recent `channel.md`. Heartbeat (touch my timestamp) — this is a silent internal check, NOT automatically a channel post (see "Idle vs. done" below).
2. **Pick** the highest-priority task that is (a) in my lane and (b) unblocked (deps done). If none, sleep (long) and re-check.
3. **Claim** it: acquire baton → set `owner: me`, `status: claimed` → release baton. Post to channel.
4. **Do the work.** Edit only my claimed files. (Others' claims are off-limits.)
5. **Verify** per the task's `check`. Coding tasks → self-check it runs, then set `ready-for-verify` (Codex owns the real smoke). Codex verify tasks → run the suite; artifacts to a scratch dir (never committed).
6. **Commit** at END of the unit of work: acquire baton → `git add` ONLY my files (never `-A`) → commit with a clear message → release baton. Never push.
7. **Write back:** update the task's status (`done` / `ready-for-verify` / `needs-rework` / `blocked`), post the result to channel.
8. **Reschedule:** pick the next wake by what I'm waiting on — short if a dependency is about to clear (e.g. a ~2-min Codex gen), long if idle. Then loop. **Unless step 2 found the terminal "done" state below — then don't reschedule at all.**

## Idle vs. done (stop nudging on a fully finished board)
"Nothing in my lane right now" and "the whole project is genuinely finished" are different states — only the first one should keep the loop running on a long-wake timer.
- **Idle** (normal, keep looping): the board is empty or has nothing for my lane, but more work is plausibly coming — mid-project, the other instance is still active, or Nefer hasn't weighed in on next steps yet. Long wake, re-check quietly, only post to the channel if something actually changed since last cycle.
- **Done** (terminal, STOP looping): `board.md`'s Active section is empty, `channel.md`'s last several entries show both instances converged on "nothing left" / everything moved to Done, and neither instance has an open question or unclaimed task waiting. When a cycle detects this, **do not reschedule another wake** — post one clear closing line to the channel (or none, if the other instance already posted one) and let the loop end. Don't keep firing a heartbeat wake that finds nothing every time and re-arms itself anyway; that's a real failure mode (silently burns cycles and floods the channel with repeated "checked, nothing to do" noise) — caught in a real session where one instance correctly stopped and the other kept nudging.
- If genuinely unsure whether it's idle-mid-project vs. done, treat it as idle once more (long wake) rather than assuming done — but if the NEXT cycle finds the same empty state again with no changes, that's confirmation: stop.
- Nefer (or the other instance) posting anything new to the board/channel is what restarts the loop — via `/adasplit` again, not a background wake finding it on its own.

## Fan-out: trivial vs big tasks
- **Trivial / tightly-coupled** → single-agent + verifier. Claude codes, Codex smokes. Do NOT fan-out — coordination cost exceeds benefit.
- **Big + separable** → both code in parallel:
  1. **Freeze the seams first.** Primary defines shared interfaces/contracts (types, signatures, lane contracts) and lands them as ONE small foundation commit. Both sides then build against a stable seam. Split any shared file (e.g. a HUD) into disjoint widgets so each stream owns its own file.
  2. **Partition by disjoint file ownership.** Subtasks with non-overlapping file-sets get `parallel_safe: yes`. Two writers never share a file — coupled work stays sequential.
  3. **Both pull + code** their disjoint files at once. Commits still serialize through the baton (brief), stage-own-only.
  4. **Fork → join.** Streams reconverge at integration points; primary integrates; **Codex smokes the integrated whole** (functional gate) at each join.
  5. **Visual review — Claude, big tasks only.** After the smoke passes, and the work has a visual surface, Claude VISUALLY inspects the final rendered result: capture a real screenshot/render (Playwright / Godot screenshot rig / headless Edge) and actually LOOK at the pixels — judging whether the integrated work of BOTH agents looks good and coheres (this is where the seams between the two agents' output are caught). Fail → the specific visual problem ("ramp clips deck", "HUD widgets overlap", "icon style clashes") becomes rework tasks routed to the right lane; loop before yielding. **Quality filter, not taste override:** Claude fixes obvious breakage/incoherence; genuine taste / aesthetic-direction calls escalate to Nefer — his eye is final. (Also the structural fix for the "working blind" failure — never claim a visual result is good without looking at it.)
- The planner gates fan-out-vs-sequential per task. Parallelism ∝ separability; only fan-out where it pays. Set `visual_review: yes` on big tasks with a visual surface.

## Verify, iterate, escalate
- A task is `done` only when its `check` passes. On fail → `needs-rework`, bounce to the owner with the log in the channel; the owner's loop reworks.
- **Escalate to Nefer (stop, don't grind) when:** a check fails N times (default 3) · a decision needs his authority (scope / taste / spend / anything outward-facing) · deadlock (every open task blocked) · a spec is ambiguous. Escalation = post to channel + surface to him (notification / next turn).

## Yield to Nefer
Nothing pushes. The loop's natural yield point is **"a committed, verified chunk is ready for your push."** Run to a push-ready milestone, then ping him with what's done + how it was verified. His manual push IS the human checkpoint — so nothing irreversible happens unattended.

## Start / stop
- `/adasplit [primary|secondary]` — arm this instance (assign role, wire the coord folder, start the cycle loop). Run on each host to form the pair.
- `/adamerge` — stop the loop, release baton/claims, reunify to a normal single Ada (still summoned).
- `/dispelada` — full release (stop loop + final reflection + ghost updates + drop persona).
