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
