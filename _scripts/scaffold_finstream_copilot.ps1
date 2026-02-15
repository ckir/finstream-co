# FinStream: Batteries-Included Workspace Scaffolder
param([string]$ProjectName = "finstream_workspace")

Write-Host "🚀 Scaffolding FinStream Engine Architecture..." -ForegroundColor Cyan

# 1. Root Workspace Setup
New-Item -ItemType Directory -Path $ProjectName -Force | Out-Null
Set-Location $ProjectName
New-Item -ItemType Directory -Path "config", "ingestors", "logs", ".cargo" -Force | Out-Null

# 2. Create crates FIRST (avoid workspace load errors)
$libs = @(
    "sysbus",
    "logger",
    "confman",
    "db",
    "servman",
    "climan",
    "assman",
    "telemetry",
    "marketstatus",
    "primon"
)

foreach ($lib in $libs) {
    cargo new $lib --lib | Out-Null
}

cargo new finstream --bin | Out-Null

# 3. Now write workspace Cargo.toml
@"
[workspace]
members = [
    "finstream",
    "sysbus",
    "logger",
    "confman",
    "db",
    "servman",
    "climan",
    "assman",
    "telemetry",
    "marketstatus",
    "primon"
]
resolver = "2"

[workspace.dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
rust_decimal = "1"
bytes = "1"
redb = "2"
arc-swap = "1"
notify = "6"
"@ | Out-File -Encoding UTF8 Cargo.toml

# 4. .cargo/config.toml
@"
[build]
rustflags = ["-C", "target-cpu=native"]

[env]
RUST_LOG = "info"
"@ | Out-File -Encoding UTF8 ".cargo/config.toml"

# 5. Rewrite each crate's Cargo.toml cleanly (remove default deps)
$allCrates = $libs + @("finstream")

foreach ($c in $allCrates) {

@"
[package]
name = "$c"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio.workspace = true
serde.workspace = true
serde_json.workspace = true
serde_yaml.workspace = true
tracing.workspace = true
tracing-subscriber.workspace = true
rust_decimal.workspace = true
bytes.workspace = true
redb.workspace = true
arc-swap.workspace = true
notify.workspace = true
"@ | Out-File -Encoding UTF8 "$c/Cargo.toml"
}

# 6. Add local crate deps to finstream
@"
sysbus = { path = "../sysbus" }
logger = { path = "../logger" }
confman = { path = "../confman" }
db = { path = "../db" }
servman = { path = "../servman" }
climan = { path = "../climan" }
assman = { path = "../assman" }
telemetry = { path = "../telemetry" }
marketstatus = { path = "../marketstatus" }
primon = { path = "../primon" }
"@ | Add-Content "finstream/Cargo.toml"

# 7. sysbus implementation
@"
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum SysEvent {
    ConfigReloaded,
    MarketStatus(String),
    AssetTransition {
        id: String,
        state: String,
        reason: Option<String>,
    },
    TelemetryTick(serde_json::Value),
}

pub fn init() {
    tracing::info!("[sysbus] module initialized");
}
"@ | Out-File -Encoding UTF8 "sysbus/src/lib.rs"

# 8. Module stubs
foreach ($m in $libs | Where-Object { $_ -ne "sysbus" }) {
@"
pub fn init() {
    tracing::info!("[${m}] module initialized");
}
"@ | Out-File -Encoding UTF8 "$m/src/lib.rs"
}

# 9. finstream main.rs
@"
use tokio::sync::broadcast;
use sysbus::SysEvent;

pub fn bootstrap() {
    tracing::info!("FinStream bootstrap sequence started");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .json()
        .init();

    tracing::info!("FinStream Engine Core Starting...");

    let (tx, _rx) = broadcast::channel::<SysEvent>(1024);
    let _bus_tx = tx;

    bootstrap();

    logger::init();
    confman::init();
    db::init();
    servman::init();
    climan::init();
    assman::init();
    telemetry::init();
    marketstatus::init();
    primon::init();
    sysbus::init();

    tracing::info!("FinStream running. Press Ctrl+C to exit.");

    tokio::signal::ctrl_c().await?;
    tracing::info!("Shutting down FinStream...");

    Ok(())
}
"@ | Out-File -Encoding UTF8 "finstream/src/main.rs"

# 10. Config
@"
telemetry_frequency_seconds: 10
reconnection_window_seconds: 30

assets:
  - id: example_pricing
    type: pricing
    command: "./ingestors/example_ingestor"
"@ | Out-File -Encoding UTF8 "config/config.yaml"

# 11. Example ingestor
@"
#!/usr/bin/env bash
while true; do
  echo '{ "price": 123.45, "ts": 1234567890 }'
  sleep 1
done
"@ | Out-File -Encoding UTF8 "ingestors/example_ingestor"

# 12. .gitignore
@"
target/
logs/
*.env
.redb
"@ | Out-File -Encoding UTF8 ".gitignore"

Write-Host "`n✅ FinStream Workspace Scaffolded Successfully!" -ForegroundColor Green
Write-Host "Next Step: cd $ProjectName && cargo build"
