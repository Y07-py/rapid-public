use once_cell::sync::OnceCell;
use serde::Deserialize;
use std::env;
use std::fs;

static FIREBASE_CONFIG: OnceCell<FirebaseConfig> = OnceCell::new();

const FIREBASE_CONFIG_PATH_ENV: &str = "FIREBASE_CONFIG_PATH";

#[derive(Debug, Clone, Deserialize)]
pub struct FirebaseConfig {
    pub project_id: String,
    pub private_key_id: String,
    pub private_key: String,
    pub client_email: String,
    pub token_uri: String,
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("Environment variable {0} not set")]
    EnvVarNotSet(String),
    #[error("Failed to read config file: {0}")]
    FileReadError(#[from] std::io::Error),
    #[error("Failed to parse config JSON: {0}")]
    ParseError(#[from] serde_json::Error),
    #[error("Config already initialized")]
    AlreadyInitialized,
    #[error("Config not initialized")]
    NotInitialized,
}

pub fn init() -> Result<(), ConfigError> {
    let config_path = env::var(FIREBASE_CONFIG_PATH_ENV)
        .map_err(|_| ConfigError::EnvVarNotSet(FIREBASE_CONFIG_PATH_ENV.to_string()))?;

    let content = fs::read_to_string(&config_path)?;
    let config: FirebaseConfig = serde_json::from_str(&content)?;

    FIREBASE_CONFIG
        .set(config)
        .map_err(|_| ConfigError::AlreadyInitialized)
}

pub fn get() -> Result<&'static FirebaseConfig, ConfigError> {
    FIREBASE_CONFIG.get().ok_or(ConfigError::NotInitialized)
}
