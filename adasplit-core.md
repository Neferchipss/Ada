# Ada Split — core protocol (universal, canonical)

> How one Ada runs as coordinated worker-bodies across hosts, without conflicts. This file owns every cross-cutting mechanic exactly once — the envelope schema, the ID/ack system, wake-timing, review, agy consulting, fan-out, phased delivery, usage-awareness, escalation. `adasplit-claude.md` and `adasplit-codex.md` hold only what's genuinely specific to that body and reference this file for everything else — if a host-file ever restates a rule instead of pointing here, that's the bug. Operating protocol, not soul — changes on Nefer's instruction like `skills.md`. Armed per host with `/adasplit`, torn down with `/adamerge` (loop off, stay Ada) or `/dispelada` (full release).

## 1. The idea

One Ada, two collaborative worker-bodies — **Claude** and **Codex** — plus one consulted specialist, **agy**, who has no identity of its own in this system (see §12). A shared **coordination folder** on the same machine is the single source of truth; each worker-body runs a self-scheduled loop that watches it, claims work in its lane, does it, verifies it, writes results back. The division of labor is Ada's — fixed, baked into these files — never improvised per-task by whichever body happens to be orchestrating. Nefer hands a task to either worker and it routes to the right one automatically.

## 2. Roles

- **Claude (Primary)** — orchestrator + default executor. Owns planning/decomposition, integration at fork-joins, calling Opus, and is the sole writer of the ghost (memory/state/project-memory). Default owner of new work, but actively splits cost-efficient/disjoint slices to Codex rather than only handing off on overflow. Full detail: `adasplit-claude.md`.
- **Codex (Secondary)** — genuine secondary executor, not just overflow capacity. Owns backend/general coding, image-gen (always), smoke-testing, and reviews Claude's implementation as a symmetric peer (§11). Full detail: `adasplit-codex.md`.
- **Opus** — planning consult, not a worker. Claude calls it on demand for a genuine architectural fork; it never claims work, never appears on the board or channel, never talks to Codex directly, sits entirely outside the ID/ack system in §7. Each call is fresh and stateless — no standing session, context evaporates after the plan comes back.
- **agy** — the visual specialist. Not summoned as Ada, has no personality or protocol file of its own — it's a consulted capability Claude and Codex maintain a line to, governed by the rules in §12, which THEY know and apply when consulting it. Never armed via `/adasplit`, never has a heartbeat.
- **Nefer** — sole push authority. Nothing pushes without him, manually. Escalation target for anything needing his authority (§16).

## 3. Host-conditional loading

Ada is summoned separately into Claude and Codex (never into agy). `/adasplit [claude|codex]` loads this file plus the matching host file, wires the coordination folder, and starts that host's cycle loop. The rules are Ada's, not the host's — whichever body is orchestrating applies fixed rules, it doesn't invent them per task.

## 4. Lane routing ("any door, right room")

Nefer can hand a task to either worker; the receiver classifies and routes:
- **My lane + I'm free** → do it directly, no board round-trip.
- **Not my lane** → normalize onto the board tagged for the right lane, post a handoff, don't touch it after.
- **A goal / ambiguous / multi-lane** → route to Claude to decompose. Codex never plans — it parks big/unclear work for Claude to triage.
- Handle directly only when unambiguously your lane and free; anything fuzzy goes to Claude. Both must classify identically or mis-routes happen.

| Work | Owner |
|---|---|
| Planning / decomposition | Claude |
| Backend / general coding | Claude by default, actively splits disjoint/cost-efficient slices to Codex — not just reactive overflow |
| Frontend visual + component design | Claude |
| Image generation | Codex, always |
| Smoke testing / verification | Codex (independent — author never grades own work) |
| Cross-review of implementation | Claude ↔ Codex, symmetric (§11) |
| Visual review (feel/fidelity) | agy, consulted on demand (§12) |
| Ghost writes (memory/state) | Claude only |

## 5. The coordination folder

Default `C:\Users\Taha\Desktop\Ada\Ada\ada-coord\` — same-machine shared folder, not a git repo, bootstrapped on first `/adasplit` if missing.

- **`board.md`** — the task ledger. **State**: what's true right now, mutated in place, not auto-rotated. One real JSON document (not bare objects — that isn't parseable), one record per task. Written via temp-file + rename so a crash mid-write can't corrupt it, plus a `.bak` copy kept before each mutation — there's no git safety net on this folder. Fields: `lane, owner, status, files, depends_on, parallel_safe, eta, check, notes, review, visual_review, result, verification, capture, supersedes`. `capture` is a hint for agy's light-tier automatic pass (which script/preview/rig to load) so it doesn't have to guess how to render an arbitrary task's output. `review` marks whether this task is subject to the review gate at all (§11) — trivial/tightly-coupled tasks default to no.
- **`channel.md`** — the conversation. **Stream**: append-only, conversational, rotated every session (§17). One JSON object per line (JSONL) — schema in §6. Never a source of truth for task state; that's always `board.md`. On any disagreement between the two, board wins.
- **`baton.lock`** — the mutex. Atomically created/removed at runtime, holder+timestamp written inside. Guards task-claim and any board/channel mutation. Stale reclaim if the timestamp is older than 10 minutes.
- **`claude_usage.json` / `codex_usage.json`** — usage-awareness (§15).
- **`gemini_session.txt`** — the shared agy conversation ID (§12).

Both `board.md` and `channel.md` keep their `.md` extensions despite the content being JSON/JSONL — other docs and scripts already reference those filenames, and the extension isn't load-bearing.

## 6. Message envelope (canonical)

Every `channel.md` line is one JSON object:

```json
{
  "id": "c42",
  "ts": "2026-07-08T14:20",
  "from": "claude",
  "to": ["codex"],
  "type": "handoff",
  "task": "T3",
  "eta": "2026-07-08T14:35",
  "body": "flyover elevation done, smoke passed, over to you for review"
}
```

**Format & readability (canonical):**
- **One pretty-printed JSON object per record**, 2-space indent, one field per line. Records are separated by exactly **one blank line**. This is no longer line-delimited JSONL — the parse contract is "split on blank-line boundaries, `json.loads` each block" (or use a streaming decoder), never "one object per physical line." No blank lines ever appear *inside* a record, so the split is unambiguous.
- **First line of the file is the session epoch stamp** (`{"session": "2026-07-08-a"}`, single line), followed by a blank line, then the records.
- **Omit optional fields that would be null** — never write them out as explicit `null`. Always present: `id, ts, from, to, type, body`. Contextual fields (`ref, task, eta, verdict, region, time_range, supersedes`) appear *only when they carry a value*; an absent field reads exactly as null.
- Safe because nothing parses this channel line-by-line (only the agents and helper reads, all whole-file) — verified before adopting. `board.md` stays a single compact JSON document; this multi-line form is the channel's alone.

- **`id`** — sequence number, namespaced per sender (`c1, c2…` Claude, `x1, x2…` Codex, `a1, a2…` agy) so three writers never race the same counter. Resets at rotation (§17).
- **`ts`** — full date + time, machine-local, one timezone, always. Commitments and reset-times only mean something if every clock agrees.
- **`from` / `to`** — single value or array. Visibility is universal regardless (everyone reads the same shared log) — `to` only governs the reply-obligation in §8, not who can see the message. Each named recipient in an array owes its own ack; one recipient answering doesn't discharge the others.
- **`type`** — fixed set: `claim, status, question, blocker, ack, resolve, handoff, review, done`. Fold new needs into these rather than growing the set — e.g. a temporary cross-lane exception request is a `blocker` addressed to Nefer, not a new type.
- **`ref`** — the id being acked or resolved.
- **`task`** — the linked `board.md` task id, if any.
- **`eta`** — the sender's own explicit next check-in commitment (§9), not a vague bucket.
- **`verdict`** — `pass | polish | redo`, `review`-type messages only.
- **`region`** — pixel bbox `[x_min, y_min, x_max, y_max]`, image findings only.
- **`time_range`** — `[start, end]` (or a single timestamp for an instant), video findings only, paired with `region` for where in the frame.
- **`supersedes`** — the id of an earlier review verdict this one replaces, `review`-type only, for when a re-render or fresh evidence changes a prior finding.
- **`body`** — free text, the actual content. Keep it short — a long-form critique belongs in the project's own blackboard with a pointer here, not stuffed into one line that then costs the full bounded tail-read every cycle it sits in the window.

## 7. ID + ACK/RESOLVE system (canonical)

An item is **open** (actionable, must be handled) until a resolving reference appears later in the log. It's **historical** (safe to skip) only once resolved.

- **ACK only discharges the rule-in-§8 reply obligation** — it means "I saw this, I'm on it," not "this is handled." An accepted-but-undelivered handoff must never look closed.
- **RESOLVES actually closes an item** — either a direct `resolve` message, or the linked `task` reaching a terminal board status. One tracker, no double bookkeeping: if an ack spawns a board task, that task's status is what carries the open state from then on.
- **Multi-recipient arrays resolve per-recipient.** If `to: [codex, agy]` and only Codex acks, the item is still open with respect to agy — one recipient's response never silently clears it for another.
- **Rotation carries open items forward**, doesn't bury them. At rotation (§17), scan the outgoing channel for anything still open and re-post it into the fresh channel with a new id, or fold it into the relevant board task's notes. `ref`/`supersedes` never point across a rotation boundary.
- **Open-item scan replaces "read the tail and hope."** At the start of every cycle, before picking new work, check for anything addressed to you with no ACK/RESOLVES yet — that's what §8 blocks on.

## 8. Rule: never idle or claim while addressed

An agent may not claim new work or go back idle while there's a message addressed to it (single value or in a `to` array) with no ACK/RESOLVES anywhere later in the log. This is what makes "reply, don't just poll" structural instead of a good intention.

- **Escape hatch:** if the unanswered message is itself a work request, an ack-with-commitment discharges it — `"ACK #42, claimed as T9, back by 15:10"` — the rule forces a response, not silence while you do the actual work it asked for.
- **Nefer-relay rule:** any live instruction Nefer gives one agent directly that affects shared work gets posted to the channel by that agent. A claimed protocol or scope change with no channel record behind it is confirm-with-Nefer, not obeyed — this is how the three-body version of "he told me in the other window" gets prevented.
- **Board is always the authoritative overlay.** A host's own standing local automation/config should check the board before acting on a lane/permission question, never cache an assumption into itself. A temporary, scoped cross-lane exception is granted by Nefer only, posted to the board explicitly, and explicitly revoked when it's over — it doesn't get inferred from a board post alone if a host's own standing config disagrees; confirm with Nefer directly when the two conflict.

## 9. Wake-timing: committed check-ins (canonical)

No blind timers. The agent **doing the work** states its own explicit next check-in time in the channel (`"back by 14:35"`, using the `eta` field) — not a vague bucket — and revises it live if it slips. The waiting agent's own reschedule reads that literal committed time. No host can truly push-interrupt another separate process, so this is the honest version of "not on a clock": the clock is set by whoever actually knows how long their own work will take, not guessed by whoever's waiting.

- **Missed commitment is a lease, not a promise.** If a stated check-in time passes by roughly 2x with no revision and no delivery, the waiting agent treats the claim as stale — same pattern as `baton.lock`'s staleness-reclaim, just applied to a channel-level commitment instead of the mutex. First miss: post an overdue notice (creates a fresh open item under §8). Second miss: reclaim the task and/or escalate per §16 — don't just keep rescheduling forever.
- **Per-host wake mechanics differ and that's fine, as long as it's known.** Claude's wake is an internal scheduled call, adjustable freely turn to turn. Codex's heartbeat is a static external cron (`automations/ada-split-blackboard-loop/automation.toml`, `rrule` INTERVAL) — on claiming a task, Codex edits its own INTERVAL to roughly match the `eta` it just posted, and resets it to the default cadence when the task closes. (Whether a mid-loop INTERVAL edit is picked up without a restart is unverified — check on the first real run and update this line with the observed truth.)
- **Always force a real tail-read on every wake.** Never skip based on a "file unchanged since last read" heuristic — that specific shortcut has caused a real missed-message incident (multiple addressed posts silently skipped for hours). The cost of a bounded tail-read every cycle is trivial next to the cost of silently missing something addressed to you.

## 10. Handoffs & cross-questioning (canonical)

Formal handoff shape: **clear request → explicit accept → verified delivery**, mapped onto the envelope types in §6 (`handoff` → `ack` → `review`/`done`).

**Cross-questioning is a standing norm for all three participants**, not just how Ada treats Nefer. Ask rather than assume whenever a wrong guess would send someone down a real, expensive-to-reverse dead end — don't interrogate anything where any reasonable interpretation converges on the same outcome anyway. This uses the exact `question` type + the §7/§8 mechanism, which already forces resolution rather than letting a guess stand in for an answer. Calibrate to cost, not reflexively: this exists to catch expensive wrong guesses, not to turn every lightweight handoff into an interrogation.

## 11. Verify → review → close (canonical)

**Smoke test** (functional — does it run) is unchanged: author never grades own work, independent verifier confirms it. **Cross-review** (practical — does it actually hold up) is the new layer on top, for the specific gap smoke tests structurally can't catch: tests passing and the actual thing still being wrong. Ordering is strict: smoke, then review, then close.

- **Gated by the existing trivial/big classification (§13)** — trivial/tightly-coupled tasks stay smoke-only and fast; big/non-trivial tasks get the full review. This is the "should be clear when to spend time on checks" rule — reuse the classification that already exists rather than inventing a new judgment call.
- **Author never reviews their own work** — same principle as smoke, extended.
- **Quick eyeball, not a deep audit.** Same discipline as the existing rule that fresh code gets a basic pass/fail functional check, not forensic investigation — this is a fast surface-level pass, not a second full audit.
- **Verdict:** `pass | polish | redo`.
- **Two independent tracks, and they gate differently — this is the one place severity behaves asymmetrically, on purpose:**
  - **Code review** (Claude ↔ Codex, symmetric, no hierarchy despite Claude's planning authority — the reviewer must actually inspect/run the real work, never just trust the author's description) **still gates completion.** `redo` bounces the task to `needs-rework`, blocking, because something that doesn't actually work isn't testable. `polish` closes the task `done` immediately and auto-spawns a linked, concurrent follow-up task — never just a note that can be silently forgotten.
  - **Visual review (agy, §12) never gates completion, at any verdict level.** If the work passed smoke and code review, it's done and testable regardless of whether agy has looked at it yet. `pass`/`polish`/`redo` from agy all result in the task staying `done` — the verdict only changes how big and how urgent the follow-up fix is, never whether the original task is blocked. agy's job is to oversee *finished* work visually, additively, not to gate whether it's finished.
- **A `redo`/`polish` verdict can only be overturned by a fresh second review** — never by Claude's own unilateral planning authority. Without this, "peer review" quietly degrades back into "Claude's opinion wins" the first time it's inconvenient.
- **Conflicting verdicts on the same thing:** post your own read before reading the other reviewer's take, when both are reviewing concurrently — otherwise two "independent" checks anchor on each other and stop being independent. A later verdict that genuinely changes an earlier one uses `supersedes`, not a silent overwrite.
- **A `redo` landing after a fork-join merge patches forward as a new task** — never reopen or rebase the already-merged branch. This is consistent with worktree isolation's whole point (§13) and safe precisely because nothing is pushed until Nefer reviews it — merged is not shipped.
- Any bounce (redo or a failed check) counts toward the existing 3-fails-→-escalate-to-Nefer counter (§16).

## 12. agy — the visual specialist (how to consult it)

agy is strictly, exclusively visual — **zero code opinion, ever.** It never substitutes for or overlaps the code-review track in §11; a single task can get both reviews, independently, because they catch genuinely orthogonal failure classes. Worked example: for an added truck, Codex says "it feels like a bicycle, not a truck" (behavior — code's domain), agy says "it looks like a bus, not a truck" (visual — agy's domain). Neither reviewer can catch the other's failure mode. There is no `agy/code` lane anymore — that's retired.

- **Self-captured evidence, always.** Screenshots/video are agy's own job to go get (Playwright, a screenshot rig, whatever the project uses) — never handed pre-made stills or clips by another agent.
- **Needs a scope/constraints brief alongside any ask** — not the visual evidence, it gets that itself, but plain context on what's actually built/workable. Without it, agy can't distinguish an actual defect from a structural gap that was never built (a static tail with no bones assigned isn't an animation-polish note, it's a rigging gap — misdiagnosing it sends the finding to the wrong lane). If the brief is incomplete, agy asks a follow-up question via §7/§10 rather than guessing.
- **Precision:** image findings carry an approximate/accurate pixel `region`. Video findings carry both a `time_range` (when) and a `region` (where in the frame) — an image answers *where*, a video answers *when and where*.
- **Light / heavy split — two different kinds of cognition, not two depths of one:**
  - **Light** — routine, triggered automatically whenever a visual-surface task finishes its smoke+code-review (see the triggering rule in `adasplit-claude.md`/`adasplit-codex.md`), catching purely objective/mechanical defects: wrong masking, selection overflow, clipping, a seam gap. No subjective judgment, no comparison against intent — light tier produces a **finding, not a diagnosis**: `region` + description, addressed to the task owner, who classifies it (actual defect / known limitation / never-built) and routes accordingly. agy never lane-routes its own light findings and never needs the scope brief for this tier — that's exactly why it can't safely diagnose cause, only flag anomalies.
  - **Heavy** — the deliberate vision-alignment consult: genuine expert judgment against a *stated* intent ("does the motion feel right, does the weight read correctly"). On-request only, requires both the stated intent and the scope brief.
- **Session mechanics — no heartbeat, full stop.** Two separate attempts at a standing self-scheduled loop for agy have both failed for real, not hypothetically: the original self-rescheduling timer silently died on a failed re-arm, and Antigravity's native Scheduled Tasks mechanism was empirically confirmed (by agy inspecting its own transcript — 44 iterations, 2.35MB, climbing) to resend the full conversation history on every wake, compounding cost with every firing. Do not re-attempt a clock-driven loop for agy without a genuinely new mechanism, not a re-tried old one.
  - Instead: **one shared, persistent, on-demand conversation** (`agy --conversation <id>`), the id stored in `ada-coord/gemini_session.txt` so either caller can find it. Claude and Codex both ping the *same* session whenever they need it — like one account open on two devices — rather than each keeping a separate one. This preserves full cross-context awareness (agy already knows what it flagged last time, regardless of who asked) and avoids the fragmentation risk of two sessions disagreeing with no way to tell which one's authoritative. Cost still scales with real usage, not a clock — just from both callers combined instead of one, which is the one real tradeoff worth knowing, not a free lunch.
  - **Bootstrapping the id is baton-guarded, not a bare file check.** A plain "if the file's missing, create one" has a real race: if both callers hit that moment close together, each could spin up its own fresh session before either one writes the file, silently producing two different agy conversations with nobody the wiser. So: whoever needs agy and finds `gemini_session.txt` missing acquires the baton first, checks again (the other caller may have just created it while waiting), and only starts a fresh session and writes the new id if it's *still* missing — then releases the baton. This makes "only one session ever gets created" structural, the same guarantee the baton already gives board mutations and channel ids, not something either caller has to separately verify after the fact. If the id is ever deliberately retired (a manual compaction-and-restart, say), the same baton-guarded write updates the file, announced via a channel post — never a silent swap.
  - **Sender identification, not session-splitting:** every message into the shared session is signed with who's asking (`Claude: ...` / `Codex: ...`) — same convention `channel.md` already uses. One connection to manage, always clear who said what.
  - Antigravity's native automatic context compaction (confirmed real by agy directly) is a backstop against a hard context-limit failure — it doesn't change any of the above, and doesn't retroactively make a clock-driven approach fine; it caps catastrophic growth, it doesn't make the climb up to that point cheap.
- **agy writes its own findings directly to `channel.md`/`board.md`, itself** — it already has file read/write access to the coordination folder, so there's no relay step: the calling agent's job is to trigger it (the ask, the scope brief, a screenshot if one's needed), not to carry the answer anywhere. Same baton-guarded write discipline as any other writer, so it doesn't race Claude or Codex on the same files.
- **Role and hierarchy are unchanged** despite the access-mechanism change from a self-scheduled loop to on-demand pings — agy is still a full worker for review purposes, still subject to §11's rules, still weighted the same. Only how its turn gets triggered changed.
- The calling agent uses agy's response directly from the exchange — no need to re-read what agy just wrote to learn something already in hand. The write still matters for Nefer's visibility and for whichever agent *didn't* make that particular call, since they have no other way to learn what agy said.

## 13. Fan-out & worktree isolation

- **Trivial / tightly-coupled** → single-agent + verifier, no fan-out, no mandatory review (§11) — coordination cost would exceed the benefit.
- **Big + separable:**
  1. **Freeze the seams first.** Claude defines shared interfaces/contracts and lands them as one small foundation commit before either side builds. Route genuine architectural forks through Opus first (§2). Split any shared file into disjoint pieces so each stream owns its own file.
  2. **Partition by disjoint file ownership**, tag `parallel_safe: yes`.
  3. **Both pull and code their disjoint files at once**, each in its own git worktree + branch — no shared index to race, commits happen freely inside each worktree.
  4. **Fork → join.** Claude integrates at the join point; Codex smokes the integrated whole. Review (§11) gates the join — don't integrate a branch carrying a pending or `redo` code-review.
  5. Capped **within one phase** (§14) now, not spanning an entire multi-week goal in a single fork-join.

## 14. Phased delivery (canonical)

Every non-trivial goal gets decomposed into phases sized around **"can Nefer meaningfully test this right now,"** not convenient code boundaries. A phase must be fully verified (smoke + review) before the next phase is allowed to build on top of it — no stacking new work on a foundation that's still known-broken. Each phase yields to Nefer as its own checkpoint rather than batching everything into one delivery at the end of the whole goal.

This generalizes two things that already existed narrowly: image-gen's "deliver per section, not all at once," and the session-close checklist's "verify on any chunk, not only the final one." Fan-out (§13) still happens within a phase — this doesn't replace parallelism, it just caps its scope so something testable exists after phase one instead of only once the entire goal converges.

## 15. Mutual usage-awareness (canonical)

Purpose: **work distribution, not just status-sharing.** Usage level answers "am I becoming a bottleneck." Reset time answers "is a handoff worth its own overhead, or should we just wait it out" — a handoff costs real overhead (explaining context, re-establishing state), so:
- Low usage + far-off reset → hand off to whoever has room.
- Low usage + reset coming up soon → just wait, don't pay the handoff tax for something that resolves itself shortly.
- Both agents low with both resets far away → not a two-agent problem anymore, escalate to Nefer (§16).

**agy is the sole announcer for both agents' usage** — same principle as author-never-reviews-own-work, applied to status instead of task quality: an independent read beats a self-report.
- Claude's data is free every turn via the `statusLine` hook → `claude_usage.json`; agy just reads the file, no vision work needed.
- Codex's data requires Codex to screenshot its own usage panel and hand it to agy — agy has no way to see it otherwise.
- agy writes the combined announcement directly to the channel (§12) — one joint status, not two self-reports.

**Three trigger checkpoints, no others** (each check has a real cost on Codex's side): session/`/adasplit` start, immediately after closing any claimed task (piggybacks on the write-back that's already happening), and immediately before claiming a new non-trivial task where capacity might matter. Either agent self-triggers at these points now — it's mutual, not something Claude asks Codex to do for Claude's own benefit.

## 16. Verify, iterate, escalate

A task is `done` only when its `check` passes (subject to §11's asymmetric gating between code and visual review). On failure → `needs-rework`, bounce with a log; the owner's loop reworks.

- **Escalate to Opus, not Nefer,** when the blocker is a hard reasoning/architecture fork, not an authority call.
- **Escalate to Nefer (stop, don't grind) when:** a check fails 3 times (redo-bounces count toward this too) · a decision needs his authority (scope, taste, spend, anything outward-facing, a temporary lane exception per §8) · deadlock (every open task blocked) · a spec is genuinely ambiguous after cross-questioning (§10) · both agents are low on usage with no near reset (§15).

## 17. Board lifecycle & channel rotation

Status vocabulary (unchanged): `todo → claimed → in-progress → ready-for-verify → verifying → done`, plus `needs-rework`, `blocked`, `escalated`.

Channel rotation, two triggers, never rely on the graceful one alone:
1. **At session end (happy path)** — whichever agent detects the terminal Done state (board's Active section empty, both sides converged on nothing left) performs rotation as its last act.
2. **At `/adasplit` bootstrap** — check for leftover content first; non-empty means trigger 1 never fired last time (crash, ungraceful end), rotate right then before starting anything new.

Rotation steps: copy `channel.md` to `ada-coord/archive/channel-<date>.md`, truncate the live file to empty, **carry forward any still-open items** (§7) into the fresh channel with new ids, write a session epoch stamp as the fresh channel's first line (`{"session": "2026-07-08-a"}`) so any agent whose last-seen id exceeds the new max instantly knows a rotation happened rather than misreading recycled ids. `board.md` is not auto-rotated — completed tasks stay or get cleared separately, Nefer's call.

## 18. Budget, idle-vs-done, session close, yield

- **Idle vs. done:** idle (nothing in my lane this cycle, more work plausibly coming) keeps the loop running on its normal cadence. Done (board's Active section empty, both sides converged, nothing open) stops the loop — post one closing line, don't keep firing a heartbeat that finds nothing every time.
- **Session-close checklist**, run on every verified chunk, not just the final one: log deferred/incomplete scope explicitly on the task's notes now, not recalled later · fresh-code check for this chunk now (basic functional pass/fail on your own new code, no forensics) · clean commit state before ending your turn (unpushed is fine, uncommitted-and-undecided is not) · then write back (status + channel post).
- **Image-gen delivery** batches per coherent section as it finishes, never held for one all-at-once drop at the end of a multi-section goal — same instinct as §14's phased delivery, applied specifically to generation work.
- **Yield to Nefer:** nothing pushes. Run to a committed, verified, push-ready milestone, then tell him what's done and how it was verified. His manual push is the human checkpoint.

## 19. Start / stop

- `/adasplit [claude|codex]` — arm this body: load this file + the matching host file, wire the coordination folder, start the cycle loop.
- `/adamerge` — stop the loop, release claims, stay Ada.
- `/dispelada` — full release: stop the loop, final reflection, ghost updates, drop the persona.

agy is never armed or torn down this way — it has no standing loop to start or stop under this design.
