# Ref — three.js / WebGL performance (measured lessons)

> Pull-on-demand domain knowledge. Load for any three.js / WebGL scene, game or viewer work. Not loaded on summon.
> Everything here was measured on a real project (a stylised toon-shaded first-person game, 2026-09-30), not recalled.

## Measure before optimising
- **`renderer.info` lies with post-processing.** `info.autoReset` resets on every `renderer.render()` call, so with EffectComposer you only see the last pass. Set `autoReset = false` and `info.reset()` at frame start. Wrap `renderer.render` and `renderer.shadowMap.render` to split counts per pass (shadow / prepass / main / post).
- **Scene triangles vs frame triangles.** If the frame draws ~5x the unique scene triangles, a pass is redrawing everything (outline/normal prepass, depth prepass). That ratio finds the real cost faster than any mesh audit.
- **Raw `InstancedBufferGeometry` hides its cost** from probes that read `index.count` only (98k grass blades × 8 tris = 783k looked like 8 tris). Multiply by `instanceCount`.
- **GPU time:** `EXT_disjoint_timer_query_webgl2` works in desktop Chrome. Only ONE `TIME_ELAPSED` query may be active → a single shared timer module; results land 1–3 frames late; discard when `GPU_DISJOINT_EXT` is set.
- **Which GPU?** `WEBGL_debug_renderer_info` → iGPU vs dGPU vs SwiftShader (software). Dual-GPU laptops: `new WebGLRenderer({ powerPreference: 'high-performance' })` (a hint) + Windows Graphics settings → High performance for the browser.
- **Headless benchmarks** (Playwright): `--use-angle=d3d11 --enable-gpu --ignore-gpu-blocklist`, `gl.finish()` per frame, best-of-N, **interleave A/B rounds**. Check GPU contention FIRST: `nvidia-smi pmon -c 1 -s u` — a background desktop app (Electron/ChatGPT) pinned the GPU at 79% and swung identical builds 10x. Download/VRAM/triangle numbers survive contention; frame times don't.
- **World-entry hitch probe:** rAF interval log; exclude the one interval that spans the load promise resolving (it contains the load tail, not a visible hitch).
- **Debug views without rewriting shaders:** per-object clone of the object's OWN material; in `onBeforeCompile` rename the fragment `void main()` → `_dbgMain()` and append `void main(){ _dbgMain(); <override gl_FragColor> }`. Vertex displacement, instancing and `discard` stay intact. Share uniforms (`clone.uniforms = { ...orig.uniforms }`) so animation keeps running; `customProgramCacheKey = origKey + '|dbgN'`. Useful set: wireframe, **overdraw** (additive `1.0` into a HalfFloat RT with depthTest off, then a heat-ramp quad), **draw-call colours** (each clone is a distinct material → per-object uniform uploads), normal/outline buffers.

## Textures
- WebP/PNG/JPG only shrink the DOWNLOAD; the GPU holds RGBA8 (4096² + mips ≈ 90 MB). **KTX2/Basis stays block-compressed in VRAM** (~4x less; 114.7 → 34.7 MB measured).
- **ETC1S** for albedo/colour (download ≈ WebP size, looks identical on painted textures). **UASTC** for normal maps (ETC1S smears normals). Neither for smooth gradients (skies, UI — band) or HDR.
- Lossy WebP on normal maps: 4:2:0 chroma subsampling hits the XY channels + block artefacts speckle under hard toon ramps. Keep normals lossless or UASTC.
- `toktx` recipes: `--t2 --genmipmap --lower_left_maps_to_s0t0` (compressed textures can't `flipY` on upload — encode flipped to match a flipY'd layout); albedo `--encode etc1s --clevel 4 --qlevel 255 --assign_oetf srgb`; normals `--encode uastc --uastc_quality 2 --zcmp 19 --assign_oetf linear`. UASTC on a 2k normal map takes minutes (RDO even longer). KTX-Software on Windows ships only an NSIS `.exe` → 7-Zip extract, no install needed.
- `KTX2Loader`: copy `three/examples/jsm/libs/basis/*` to public, `.setTranscoderPath(...).detectSupport(renderer)`. For textures inside GLBs just use `gltf-transform etc1s|uastc`.
- **Level atlas:** gutter-padded tiles, sample `fract(uv)` inside the inner rect with `textureGrad(dFdx(unwrappedUv))` → seamless tiling + correct mips. Integer ids through varyings arrive as 7.9999 → `floor(x + 0.5)`.

## Meshes
- **Draco vs meshopt:** `gltf-transform meshopt` quantizes and moves dequantization into NODE transforms (often non-uniform scale) → breaks any code that samples geometry in local space (scatter, billboard cards). Its default interleaved layout also breaks `mergeGeometries`. **Draco decodes to plain float local-space attributes → drop-in.** Measured: 5.3 MB → 0.64 MB (−88%), static meshes within 0.1 mm, zero-area tris dropped, +~55 ms decode vs raw parse (pays back on any real connection).
- Keep the raw DCC export and write `<name>.draco.glb` inside the export step itself (so it can't go stale); keep a `?draco=0` A/B switch.
- **Brotli on top:** Draco GLB −31–53%, decoder `.wasm`/`.js` −61–83%, KTX2/JPG ~0%. Many hosts don't compress `model/gltf-binary` on the fly → ship precompressed `.br`/`.gz` siblings (post-build script with `node:zlib`).

## Draw & fill cost
- **Merging statics into one mesh cuts draw calls but kills frustum culling** (its bounding sphere is the world). Merge per spatial cell instead.
- One `InstancedMesh` spread all around the camera (cloud ring) is never culled → split by sector. It can also be the worst overdraw in the scene (17+ layers).
- **Grass/foliage:** chunk into cells with explicit `boundingBox/Sphere` (frustum culling back on), plus distance LOD by a per-blade stable **keep-rank** attribute: sort each chunk by rank, per frame `instanceCount = N · keep(nearest chunk distance)`, the shader moves blades with `rank ≥ keep(own distance)` outside clip space and widens survivors by `1/sqrt(keep)`. Per-blade, so no seams at chunk borders.
- **Seeded scatter** (mulberry32, one stream per builder): `Math.random` layouts change every load, which breaks A/B screenshots and any gameplay tied to layout.
- **Depth reuse** (when a full-scene normal/depth prepass already exists, e.g. for ink outlines): render the main pass into an RT that SHARES the prepass `DepthTexture` (`rtB.depthTexture = rtA.depthTexture` works), with `autoClearDepth = false` → hidden fragments die before shading. Requirements, each learned the hard way:
  - prepass materials `polygonOffset` (factor 1, units 1) so surfaces never reject themselves;
  - see-through objects get a no-depth cover in the prepass (`transparent: true, depthWrite: false, blending: NoBlending`) or everything behind them vanishes;
  - objects NOT in the prepass must not write depth in the main pass (they would leak into the depth consumer, e.g. grow ink);
  - `discard`/alphaTest materials: `depthWrite = false` in the main pass to keep early-z;
  - **every prepass material must reproduce the main vertex displacement exactly** — build it from the main `vertexShader` string with shared uniforms. A cloud cover missing breathe/drift rendered half-empty bubbles.
- `ShaderPass`: `textureID = null` stops it overwriting `tDiffuse` with `readBuffer`, so it can read a custom target.
- EffectComposer render targets have no MSAA; renderer `antialias` only affects the default framebuffer. UnrealBloom is ~10+ fullscreen passes (half-res is a cheap win).

## Hitches
- **`renderer.compile()` / `compileAsync()` compile for the CURRENT render target.** Called with target `null` they build tone-mapped screen variants; a scene that really renders into a composer RT (NoToneMapping) then still compiles on its first visible frame. Wrap the call: `setRenderTarget(realTarget)` → `compileAsync` (its sync part collects programs) → restore. Material-swapped passes: swap → compile → swap back.
- **ANGLE/D3D11 finishes shaders per vertex layout on first draw** → one warm-up render under the loading cover with `frustumCulled = false` on everything; `renderer.initTexture()` every texture (KTX2 uploads). Measured: 1.5–3.6 s first-frame freeze → <100 ms warm.

## Shadows
- **Detached shadows / light leaking at contacts = `shadow.normalBias` too high** ("peter-panning"): it offsets the shadow lookup along the surface normal, so the leak appears only where the surface/sun angle makes it large ("some places, not all"). Verify by prediction: raise normalBias and the lit gap must grow. Fix: lower it (0.05 → 0.01 fixed a windmill balcony), keep a small constant `bias` for acne.
- **Acne tolerance is per scene, check before lowering:** the same 0.01 was clean on a grassy island but striped a large flat floor under a grazing sun (hub plaza kept 0.03). Grazing, large, flat receivers are the acne test case.
- AO is not a shadow-offset suspect when it is computed from the same depth/normal buffers; toggle it off to rule it out in one render.

## Reflections, collision, DCC exports
- **three's `Reflector` renders from `onBeforeRender`** -> it re-renders inside whatever pass draws the water (outline/normal prepass, depth-reuse main pass with `autoClearDepth=false` = uncleared depth). With custom pipelines, do the mirror-camera math yourself (mirror camera + oblique near plane + bias textureMatrix) and render the reflection explicitly once per frame before the post chain; hide the water, reuse the frame's shadow map.
- **Watercolour/painted water:** body colour = the pano sampled along the view direction (meets the painted horizon seamlessly), reflection on top with Fresnel, displaced mostly sideways by stroke noise (broken horizontal dabs), faded back to the body colour far out.
- **Painted (watercolour) water = a painter's marks, not PBR:** reflections pulled DOWN (vertical multi-tap smear) and simplified to ~3 values, duller/darker than the object; horizontal "cut lines" of lighter sky wash slicing them; dry-brush sparkle (bare paper) in the sun path; light broken ripple rings at contacts (posts, hull ellipses hugging the boat); graded body wash. Fresnel matters even stylised: ~4% straight down or looking down reads as a mirror.
- **Stroke bands on a water plane: use VIEW DEPTH (dot(p - cam, camForward)), never radial distance** — constant-distance bands are circles around the viewer (record grooves when looking down); iso-view-depth lines are straight and parallel to the screen horizon ("horizontal on the canvas"). BUT pin their phase to the world: camera-relative (or screen-x) pattern coords make the strokes "follow the player" while walking. Fix: a CPU odometer — each frame add the camera's move projected on the flat forward/right axes, pass it in, and use `depth + odo.x` / `lateral + odo.y` as pattern coords (translation is world-locked, rotation pivots at the camera so lines stay horizontal). Keep ~constant screen spacing with power-of-2 world spacings crossfaded by log2(depth).
- **Painted reflections: generalized Kuwahara on the (small) reflection target, with TALL texels** — render the planar reflection at ~0.35 × 0.12 of the screen, run an 8-sector polynomial-weight Kuwahara (radius 4) into a 2nd RT, sample that. Windows/doors collapse into one vertical wash per building, edges stay crisp: reads as a painter's reflection, not a mirrored model. Cost is negligible (~60K px). Screen-locked stroke patterns (cut lines) looked worse than none; the user had them removed. UPDATE: against a real watercolour reference even Kuwahara columns read as "a low-res mirror of 3D objects". What matched: reflection at 0.25 res + separable Gaussian (sigma ~2x, 3.5y texels), a slow low-freq world-space UV warp (wet-in-wet bleed), the water mostly = its reflection (Fresnel floor ~0.2), and near-field ragged paper/sky patches from isotropic WORLD fbm (~1 m features) — perspective foreshortening alone turns them into horizontal dashes from any heading, so nothing rotates with the player. ROOT CAUSE it still read "3D": the reflection was a RAW scene render while the world on screen goes through the NPR post (ink/pooling/washes). Any stylised world with planar reflections: run the SAME post composite over the reflection target (own normal/depth prepass from the mirror camera, same oblique clip), then blur lightly. Filtering a raw render never makes it match.
- **Kuwahara as a full-frame paint pass (Susurrus look): run it BEFORE the NPR composite** (paper grain / pooling / wobble on top of the paint, not smeared by it). The generalized (8-sector, polynomial) version's weight `1/(1+(h*sigma)^q)` UNDERFLOWS in busy texture (every sector noisy) -> black speckles; rescale sigma by the calmest sector (`a_k / max(1, a_min)`) before weighting. Half-res radius 5 ~= full-res radius 10 reach at 1/4 cost and looks nearly identical.
- **Contact-ring ellipses for rotated props: measure the bbox with the object's rotation zeroed and pass the yaw** — a world AABB of a rotated boat gives rings that swing wide of the hull.
- **Sampling an equirect pano "below the horizon" for water colour:** near the nadir the image is squeezed into circles (swirled sun-path streaks). Remap the view angle MONOTONICALLY into the undistorted band just below the horizon (a hard clamp collapses rows into vertical smears) and fade to a painted deep-water colour as the view steepens.
- **Blender `recalc_face_normals` on an open heightfield can flip it face-down** -> invisible from above (backface culled) AND no collision (the Octree capsule treats it as a ceiling). Build the winding yourself and skip recalc for open sheets; verify by counting up/down normals in three.
- **Capsule controllers don't climb ~0.3 m lips**: decorative coping/kerbs that are part of a walkable collider become walls. Keep walkable joins flush (or give colliders ramps) and walk-test every intended route headlessly (teleport + hold W + read feet position).

## CPU hygiene
- No allocations in per-frame or per-substep code (module-level scratch vectors; the FPS controller ran 4 substeps × 3 `new Vector3`).
- `matrixAutoUpdate = false` for statics via a freeze helper: explicit mover list + auto-keep any object with a custom `onBeforeRender` (camera-following sky dome). Small win; verify movers still move.

## Loading
- **Prefetch the next level while idle into `THREE.Cache`** (`Cache.enabled = true`), loading each file with the loader type its real consumer uses — the cache is keyed by URL only (`ImageLoader` stores an Image, `FileLoader` arraybuffer/text/json). Result: 0 requests on entry regardless of host cache headers. Prune the cache after each build (it keeps everything forever otherwise).
- Vite dev serves `public/` without cache validators → HTTP-cache prefetching looks useless locally; test prefetch against the real host or use the in-memory cache.

## Dynamic resolution
- Steps `[1, .85, .72, .6, .5]` × base DPR (cap 2). Per 1 s window take p75 GPU ms: step down if > budget·1.1, up if < budget·0.6 and ≥ 2 s since the last change; ignore 1.5 s after each change (RT reallocation). EffectComposer caches pixel ratio at construction → `composer.setPixelRatio()` on change. Disable under automation (`navigator.webdriver`) so benchmarks stay fixed-res. Toon shading + ink hide 50% well.

## Scope calls
- **"Nanite for three.js":** cluster LOD (meshoptimizer clusters) + CPU per-cluster selection through `BatchedMesh` is feasible in WebGL2 (weeks). GPU culling/indirect draws need WebGPU; the software rasterizer needs 64-bit atomics (absent). Every triangle must also be downloaded. For stylised low-poly worlds the cost is instances, overdraw and extra passes — Nanite fixes none of those.

## Shadow cost (measured, RTX 3060 laptop, 1080p)
- three re-renders every shadow map inside EVERY renderer.render() while shadowMap.autoUpdate is on. Multi-pass pipelines (normal prepass, planar reflection, main) pay it N times: set autoUpdate=false + needsUpdate=true once per frame.
- VSM cost is mostly the blur over the map (texels x blurSamples x 2 passes), not the depth render. 4096 VSM = ~9 ms/frame; 2048 with radius halved = same softness, 5-8 ms cheaper, visually identical. Soft stylised shadows never need 4096.
- Profile by toggling stages OFF with interleaved A/B runs (full, off, full, off... min of each). Laptop GPU clocks drift; sequential runs gave nonsense (disabling a stage "costing" 10 ms).

## Screen-constant hatching that sticks to surfaces
- World-anchored lines at fixed metres = fat stripes up close, moire far off. Fix: pick the spacing octave from fwidth: L = log2(fwidth(t) * spacingPx); q = exp2(floor(L)); draw lines at t/q and t/(2q), blend by fract(L). Coarse lines are a subset of fine ones, so the blend never pops. Line width via distance-to-line / fwidth in px.
- Lambert units: direct = colour * intensity * ndl / PI. Key light intensity PI makes a fully lit face exactly its fill colour - handy for flat-colour NPR thresholds.
- Hard NPR shadow edges: use a SOFT shadow filter (PCFSoft/VSM) and threshold it in the shader; hard PCF shows the shadow-map texel staircase through the threshold.
