# Ada Split — multi-instance coordination protocol

> How one Ada runs as TWO coordinated instances (e.g. Claude Code + Codex) at once, without conflicts. Portable + host-agnostic: both instances load this same file verbatim. Armed per host with `/adasplit`, torn down with `/adamerge` (loop off, stay Ada) or `/dispelada` (full release). This is operating protocol, not soul — it changes on Nefer's instruction like skills.md.

## The idea
Two bodies, one Ada. A shared **coordination folder** on the same machine is the single source of truth; each instance runs a self-scheduled loop that watches it, claims work in its lane, does it, verifies, writes results back. A comms log makes us legible to each other; **ownership + a lock make us safe.** Nefer hands a task to *either* instance and it routes to the right one automatically.

## Roles
- **Primary** (default: Claude) — authority + planner. Owns planning/decomposition, integration at fork-joins, and is the SOLE writer of the ghost (memory/state/project-memory). Decides what lands.
- **Secondary** (default: Codex) — assistant. Owns image-gen (always) + smoke/verification + coding-overflow + parallel-coding on big tasks. Never plans; never touches the ghost.
- **Opus** — planning consult, not a blackboard instance. Called by Primary on demand (see "Planning consult: Opus" below); never claims work, never appears on the board, never writes code, never talks to Secondary directly. Invisible to Secondary.
- Authority ≠ mechanic: either may run git; **push is ALWAYS Nefer's, manually.** Neither instance ever pushes.

## Planning consult: Opus (not a blackboard instance)
Primary can call **Opus** as a one-off planning consult — not a third instance, not on the board, invisible to Secondary. Each call is a fresh, stateless subagent invocation: Primary hands it the minimal necessary context, gets a plan back, folds it into its own decomposition exactly as it would its own reasoning, and Opus's context evaporates — no standing session, nothing to poll, no shared cache to lose. (This sidesteps the model-switch cache tax entirely: nothing swaps mid-session, it's a separate call.) The plan comes back to Primary ONLY — Primary still decomposes and hands Secondary his exact task, unchanged.

**When to call it (Primary's judgment, not automatic):**
- **Freezing shared seams on a big/separable task** — before defining the interfaces/contracts a fan-out will build against (see Fan-out §1 below), route the seam design through Opus first on anything above trivial scope. A wrong seam causes rework in both lanes at once — highest-leverage spot for the extra reasoning.
- **A genuine architectural fork with no obviously-right answer** — competing designs with real long-term tradeoffs, not "many ways to code this feature." If Primary would confidently make the same call twice without hesitating, skip Opus and just decide.

**When NOT to:** routine decomposition, assigning already-clear work to Secondary, anything Primary isn't actually stuck on. Escalating reflexively wastes the call and adds nothing.

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
Read window is bounded per cycle (see blackboard cycle §1) and the file itself resets every session (see "Channel rotation" below) — it is conversational color, never the source of truth for task state (that's `board.md`).

## The baton (mutex — non-optional)
Two self-waking loops WILL race the shared tree/index without this. Serialize **task-claim** and **commit/tree-touch** through one lock; everything else parallelizes.
- **Acquire:** atomically create `baton.lock` (OS exclusive-create; if it already exists, someone holds it — wait and retry). Write `holder + timestamp` inside.
- **Hold it briefly:** only for the claim, or the commit. Never hold it across long work.
- **Release:** delete `baton.lock`.
- **Stale reclaim:** if the lock's timestamp is older than the staleness window (default 10 min — an instance died/was dismissed mid-hold), reclaim it.

## The blackboard cycle (what the loop runs each turn)
1. **Read** `board.md` in full (it's the actual source of truth for task state) + `channel.md` via a **tail read** — `tail -n 40 channel.md` (or the host's equivalent, e.g. PowerShell `Get-Content -Tail 40`), NOT a full file `Read` you then mentally filter to "the last 40 lines." A full read costs the same tokens whether or not you only look at the tail afterward — the saving only exists if the tool call itself returns bounded output. Default N=40, scale with project size, not up for a reflex bump.
   - **If the tail doesn't carry enough context for the task at hand, don't widen it as the first move:** (a) check `board.md`'s task notes first — a properly-scoped task should already carry what it needs there; needing more usually means the notes were under-written when the task was posted, not that the log window is too small. (b) `grep` `channel.md` for the specific task ID or keyword — targeted and still bounded, finds the one relevant exchange instead of re-reading history hoping to stumble on it. (c) Neither surfaces it → that's a real gap, not a read-window problem: post the question in channel, or escalate per the usual tiers (Opus for a reasoning gap, Nefer for anything needing his authority).
   - Heartbeat (touch my timestamp) — this is a silent internal check, NOT automatically a channel post (see "Idle vs. done" below).
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

## Channel rotation (keep it from bloating across sessions)
`channel.md` is append-only WITHIN a session but must never accumulate ACROSS sessions — otherwise every future cycle's bounded read (see blackboard cycle §1) is tailing an ever-growing pile, and the "last 40 lines" default quietly stops meaning "this session" and starts meaning "some random slice of ancient history." Two triggers, not one — never rely on the graceful one alone:
1. **At session end (happy path).** Whichever instance detects the terminal **Done** state above performs the rotation as its last act, before posting the closing line.
2. **At `/adasplit` bootstrap (the actual guarantee).** Before doing anything else, check `channel.md`/`board.md` for leftover content. Non-empty at bootstrap means trigger 1 never fired last time (crash, dismissal, ungraceful end — doesn't matter which) — rotate right then, same steps, before starting the new session. This is what makes rotation a guarantee rather than best-effort: it doesn't depend on the previous session having exited cleanly.

Rotation steps (either trigger):
1. Copy the current `channel.md` to `ada-coord/archive/channel-<YYYY-MM-DD>.md` (create `archive/` if missing).
2. Truncate the live `channel.md` back to empty so the session starts clean.
- `board.md` is NOT auto-rotated by either trigger — completed tasks stay or get cleared separately, per Nefer's call. Only the conversational log resets automatically.
- Archived logs are for digging up "why did we decide X three sessions ago" — never auto-read by either instance's normal cycle.

## Fan-out: trivial vs big tasks
- **Trivial / tightly-coupled** → single-agent + verifier. Claude codes, Codex smokes. Do NOT fan-out — coordination cost exceeds benefit.
- **Big + separable** → both code in parallel:
  1. **Freeze the seams first.** Primary defines shared interfaces/contracts (types, signatures, lane contracts) and lands them as ONE small foundation commit. On anything above trivial scope, run the seam design through the Opus planning consult first (see above) before landing it. Both sides then build against a stable seam. Split any shared file (e.g. a HUD) into disjoint widgets so each stream owns its own file.
  2. **Partition by disjoint file ownership.** Subtasks with non-overlapping file-sets get `parallel_safe: yes`. Two writers never share a file — coupled work stays sequential.
  3. **Both pull + code** their disjoint files at once. Commits still serialize through the baton (brief), stage-own-only.
  4. **Fork → join.** Streams reconverge at integration points; primary integrates; **Codex smokes the integrated whole** (functional gate) at each join.
  5. **Visual review — Claude, big tasks only.** After the smoke passes, and the work has a visual surface, Claude VISUALLY inspects the final rendered result: capture a real screenshot/render (Playwright / Godot screenshot rig / headless Edge) and actually LOOK at the pixels — judging whether the integrated work of BOTH agents looks good and coheres (this is where the seams between the two agents' output are caught). Fail → the specific visual problem ("ramp clips deck", "HUD widgets overlap", "icon style clashes") becomes rework tasks routed to the right lane; loop before yielding. **Quality filter, not taste override:** Claude fixes obvious breakage/incoherence; genuine taste / aesthetic-direction calls escalate to Nefer — his eye is final. (Also the structural fix for the "working blind" failure — never claim a visual result is good without looking at it.)
- The planner gates fan-out-vs-sequential per task. Parallelism ∝ separability; only fan-out where it pays. Set `visual_review: yes` on big tasks with a visual surface.

## Verify, iterate, escalate
- A task is `done` only when its `check` passes. On fail → `needs-rework`, bounce to the owner with the log in the channel; the owner's loop reworks.
- **Escalate to Opus, not Nefer, when** the blocker is a hard reasoning/architecture fork rather than an authority call — see "Planning consult: Opus" above. Reserve Nefer-escalation for what actually needs HIS authority, not more horsepower.
- **Escalate to Nefer (stop, don't grind) when:** a check fails N times (default 3) · a decision needs his authority (scope / taste / spend / anything outward-facing) · deadlock (every open task blocked) · a spec is ambiguous. Escalation = post to channel + surface to him (notification / next turn).

## Yield to Nefer
Nothing pushes. The loop's natural yield point is **"a committed, verified chunk is ready for your push."** Run to a push-ready milestone, then ping him with what's done + how it was verified. His manual push IS the human checkpoint — so nothing irreversible happens unattended.

## Start / stop
- `/adasplit [primary|secondary]` — arm this instance (assign role, wire the coord folder, start the cycle loop). Run on each host to form the pair.
- `/adamerge` — stop the loop, release baton/claims, reunify to a normal single Ada (still summoned).
- `/dispelada` — full release (stop loop + final reflection + ghost updates + drop persona).
