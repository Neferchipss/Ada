# Ref — Web / Python stack (gotchas + verification patterns)

> Pull-on-demand domain knowledge. Load for web app / SaaS / API work (FastAPI, Next.js, deployment). Not loaded on summon.

## Gotchas
- **FastAPI `TestClient` tears down the event loop per-request** — async jobs using `run_in_executor` + `loop.call_soon_threadsafe` from a worker thread die with "Event loop is closed". To smoke-test background-job APIs, boot a REAL uvicorn subprocess and hit it over HTTP instead of TestClient. (2026-06-09)
- **Windows: `http://localhost` from Python urllib tries ::1 (IPv6) first** and eats a ~2s fallback timeout per fresh connection against an IPv4-bound server — can poison latency benchmarks 10x (observed 2271ms → 194ms real). Always use `127.0.0.1` in benchmarks, scripts, and dev API URLs. (2026-06-11)

## Verification patterns
- **Pinned deps won't install locally?** (e.g. interpreter too new for the pinned wheels, which target the container's Python) — verify the CODE by installing whatever compatible wheels DO exist and running a real end-to-end test. Same code paths; validates wiring/logic even if not the exact pins. Beats byte-compile-only checking. (2026-06-09)
