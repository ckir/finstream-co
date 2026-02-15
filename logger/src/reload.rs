use parking_lot::RwLock;
use std::sync::Arc;
use tracing_subscriber::{EnvFilter, reload};

pub type ReloadHandle = reload::Handle<EnvFilter, Arc<RwLock<EnvFilter>>>;

lazy_static::lazy_static! {
    pub static ref RELOAD_HANDLE: Arc<RwLock<Option<ReloadHandle>>> = Arc::new(RwLock::new(None));
}

pub fn set_reload_handle(handle: ReloadHandle) {
    *RELOAD_HANDLE.write() = Some(handle);
}
