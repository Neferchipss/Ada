# Ref — Phaser (workflows + gotchas)

> Pull-on-demand domain knowledge. Load when the active project is Phaser/browser-game work (any monolithic game.html or modular browser game). Not loaded on summon.

## Phaser-specific workflows (developed 2026-06-01, monolith→modular port)
- **Phaser modular port** — apply the modular game architecture pattern (see refs/gamedev.md) to a monolithic game.html. Concrete Phaser form: GameState singleton + EventBus singleton + GameScene as glue. System interface: `constructor(scene, state, bus, cfg)`. Inject-art.js + inject-sound.js bake assets into JS modules; build.js concatenates src/ into dist/index.html for standalone play.
- **ES module → standalone build script** — Phaser games using ES modules (`import`/`export`) are blocked by CORS on `file://`. Fix: `tools/build.js` reads all source modules in dependency order, strips `import`/`export` via regex, concatenates into a single inline `<script>` in `dist/index.html`. Source stays as ES modules for dev; dist/ is the ship target. Use whenever the target is a standalone browser game that opens directly without a server.

## Phaser 3.60 gotchas (observed in production, 2026-05)
Non-obvious behaviors that don't throw but silently break things:
- **`refreshBody()` is a no-op** for dynamic bodies in this build. After any texture switch, use `body.setSize(frame.realWidth, frame.realHeight)` explicitly.
- **`textures.addCanvas(key, canvas)` silently returns null** if the key already exists. Always `textures.remove(key)` first when ART should override a procedural fallback.
- **`this.load.image(key, dataUrl)` hangs indefinitely** on base64 data URLs — Phaser's loader never calls `create()`. Use `new Image(); img.onload = () => { textures.addCanvas(key, canvas) }` in `create()` instead, and gate `scene.start()` inside `Promise.all(artPromises).then(...)`.
- **`startFollow + setFollowOffset` is absorbed by camera bounds clamping.** At world edges, offset is silently eaten. Use fully manual scroll: `baseX = clamp(player.x - vw/2, 0, W-vw)`, then add pan offset after the clamp.
- **`body.setSize(w, h, true)` recalculates body offset from the new texture's frame dims**, causing a vertical position shift on switch. Never pass `true` during a texture swap — call `setSize` without the third arg and manage offset manually if needed.
- **Physics overlap callbacks setting per-frame state get wiped** if that state is reset at the top of the same `update()`. Use direct distance checks inside `updatePlayer()` instead of relying on overlap callbacks.
