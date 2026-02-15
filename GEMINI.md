# FinStream: High-Performance Pure-Pipe Data Engine
# Unified Architecture Document (Finalized Core)

FinStream is a high-performance, single-node, “pure pipe” data engine designed to provide free, accurate, and low-latency financial/sentiment data to downstream consumers.

FinStream does not provide an end-user trading UI. It focuses on robust distribution, low latency, and resource efficiency.

---

## 🏗️ Core Engine Fundamentals

- **Runtime:** `tokio` (Async I/O) + `rayon` (CPU-bound parallelism).
- **Persistence:** `redb` (Pure-Rust embedded KV store for metadata and state).
- **Precision:** `rust_decimal` (Required for all price/financial fields).
- **Data Transport:**
  - **Internal:** `sysbus` via typed Rust enums (`SysEvent`).
  - **External:** WebSockets with JSON payloads.
  - **Buffers:** `bytes::Bytes` for zero-copy data passing where applicable.

> Internal messages are strongly typed; JSON is used only for external APIs and logs.

---

## 🧱 1. Universal System Bus (sysbus)

**Purpose:** Internal control-plane event signaling.

- **Scope:** Strictly control-plane (reloads, status, lifecycle). No tick/data-plane traffic.
- **Message Type:** Strongly typed `enum SysEvent`.
- **Reliability:** No ordering guarantees; drop-if-full semantics to ensure the control plane never stalls ingestion.

**Examples:**
- `ConfigReloaded`
- `MarketStatus(MarketState)`
- `AssetTransition { id: String, state: AssetState, reason: Option<String> }`
- `ServerControl(Command)`
- `TelemetryTick(TelemetrySnapshot)`

---

## 🪵 2. Logger (logger)

**Purpose:** Structured JSON logging with dynamic runtime reconfiguration.

- **Implementation:** `tracing` + `tracing-subscriber`.
- **Hot Reload:** Uses `tracing_subscriber::reload::Handle` to modify log levels at runtime via config updates.
- **Backpressure:** Logs are sampled or dropped if transports lag; logging must never block the data pipeline.
- **Visibility:** Kill reasons (e.g., `"BackpressureOverflow"`) are explicitly logged and broadcast to the NOC via `sysbus`.

---

## ⚙️ 3. Configuration Manager (confman)

**Purpose:** Central configuration loader with hot reload and validation.

- **Source:** `config.yaml`, watched via `notify`.
- **Representation:** Atomic `Arc<ConfigStruct>` for zero-cost read access across threads.
- **Validation:** Basic schema (“vitals”) validation on reload.
- **Reload Logic:**
  - If valid → atomic swap + `SysEvent::ConfigReloaded`.
  - If invalid → reject change, keep current config, and log the validation error.

---

## 🗄️ 4. Persistence (db)

**Purpose:** Embedded session and subscription store.

- **Engine:** `redb`.
- **Stored Data:**
  - Client UUID registrations.
  - Active subscriptions per UUID.
  - Session metadata (reconnection windows).
- **Durability:** `Durability::None` for high-frequency updates; prioritized for IOPS.
- **Recovery Model:** If state is lost, clients re-register and re-subscribe. FinStream is a **live-only** engine.
- **Config Link:** Reconnection window duration and related behavior are defined in `config.yaml`.

> Admin access is currently assumed to occur in a trusted environment; authentication/authorization for admin operations will be added in a later phase.

---

## 📡 5. Servers & Clients (servman / climan)

**Purpose:** Public interface for SDKs and NOC.

### REST (Control Plane)
- Client registration, subscription management, and arena queries.
- Admin control actions (pause/start/reboot, config reload).

### WebSockets (Data Plane & Admin Telemetry)
- Streaming datafeeds for subscribed assets.
- Real-time telemetry for the NOC.
- **Bi-directional Admin:** The NOC may send control commands over the WebSocket for low-latency control.
- **Admin commands** bypass client UUID logic until Auth/AuthZ is implemented.

### Behavior
- **Auth:** UUID-based access control for datafeeds.
- **Backpressure:** Hard-kill connection/ingestor on overflow; reason logged and broadcast via `sysbus`.
- **State:** No Last Value Cache (LVC). Clients receive “now” upon connection.
- **Admin Persistence:** Admin commands do not persist privileged state in `redb`.

---

## 📦 6. Asset Manager (assman)

**Purpose:** External ingestor lifecycle supervision.

- **Interface:** External processes via `stdout` (JSON lines) and `stderr` (logs).
- **Supervision:**
  - Launch on-demand (≥1 subscriber); stop on zero subscribers.
  - Restart on crash.
- **Graceful Shutdown:** Sends `SIGTERM` with a configurable grace period before `SIGKILL`, allowing ingestors to close exchange sockets cleanly.
- **Backpressure:** Persistent `stdout` overflow triggers a hard-kill of the ingestor process.
- **Dynamic Loading:** Ingestors can be added/removed via config reload; removal triggers the `SIGTERM` sequence.

---

## 🧮 7. Telemetry (telemetry)

**Purpose:** Real-time metrics for NOC and periodic summaries for logs.

- **Frequency:** Configurable in YAML (default ~10s).
- **Metrics:**
  - **System health:** CPU, memory, process status.
  - **Asset stats:** Ticks/sec, errors, restarts, lag summaries.
  - **Client stats:** Throughput and subscription counts.
  - **Arena distributions:** Lag histograms and degraded-source counts.
- **Outputs:**
  - Real-time WebSocket stream to NOC.
  - Periodic summaries (e.g., hourly) to logs.
- **Retention:** Real-time only.

---

## ⏱️ 8. Metronome (marketstatus)

**Purpose:** Market status oracle for Nasdaq.

- **Polling:** 1 min (open/pre/after-hours) or 1 hour (closed).
- **Behavior:**
  - Caches last known status; falls back on failure.
  - Emits `SysEvent::MarketStatus`.
  - Triggers automatic pause/resume in `assman` via `sysbus`.
- **Modes:**
  - **Live mode:** Real Nasdaq API polling.
  - **Simulation mode:** Overrides live polling entirely; state controllable via NOC.

---

## 🏆 9. Arena (primon)

**Purpose:** Competitive lag-based ranking of pricing assets.

- **Lag Calculation:** `lag = now(NY) - ingestor_timestamp`.
- **Target:** Sub-second lag.
- **Degraded Sources:** `>1s` flagged; severity increases with lag.
- **Logic:** Recalculated on every tick.
- **State:** Current session only.
- **Exposure:** Rankings via REST and `sysbus`.
- **Routing Impact:** Informational only; does not alter ranking order.

---

## 💻 10. SDKs & NOC

### SDKs
- **Languages:** Python & Isomorphic JS.
- **Features:** Auto-reconnect, no offline buffering, raw JSON exposure.

### NOC (Admin UI)
- **Stack:** SvelteKit + Lightweight Charts.
- **Capabilities:**
  - Real-time monitoring of system health, asset status, arena rankings, and kill reasons.
  - Full administrative control (pause/start/reboot, simulation mode, config reload).
- **Visualization:** Real-time only.

---

## 🚀 Deployment Model

- **Model:** Single binary, vertical scaling.
- **Environment:** VPS or bare-metal preferred.
- **Containerization:** Optional Docker images.
- **Ingestors:** Language-agnostic (JSON over `stdout`).
- **Dependencies:** `redb` is the only mandatory persistence layer.
