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
