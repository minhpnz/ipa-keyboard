//! Config file reader for the Windows IME.
//!
//! Loads from `%APPDATA%/ipa-keyboard/config.json`, falling back to the
//! bundled default config.

use ipa_mapping_engine::MappingConfig;

/// Embedded default config — compiled into the DLL.
const DEFAULT_CONFIG: &str = include_str!("../../../shared-config/default-mappings.json");

/// Load the IPA mapping config.
///
/// Attempts to read `%APPDATA%/ipa-keyboard/config.json`. Falls back to the
/// bundled default if the file doesn't exist or can't be parsed.
pub fn load_config() -> MappingConfig {
    if let Some(config) = load_from_appdata() {
        return config;
    }
    // Fall back to embedded default
    MappingConfig::from_json(DEFAULT_CONFIG).expect("embedded default config must be valid JSON")
}

/// Try to load config from `%APPDATA%/ipa-keyboard/config.json`.
fn load_from_appdata() -> Option<MappingConfig> {
    let appdata = std::env::var("APPDATA").ok()?;
    let config_path = std::path::Path::new(&appdata)
        .join("ipa-keyboard")
        .join("config.json");

    let json = std::fs::read_to_string(config_path).ok()?;
    MappingConfig::from_json(&json).ok()
}

/// Returns the path where the config file should be stored.
pub fn config_dir() -> Option<std::path::PathBuf> {
    let appdata = std::env::var("APPDATA").ok()?;
    Some(std::path::Path::new(&appdata).join("ipa-keyboard"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_parses() {
        let config = MappingConfig::from_json(DEFAULT_CONFIG).unwrap();
        assert!(config.cycle_timeout_ms > 0);
        assert!(!config.mappings.is_empty());
    }

    #[test]
    fn load_config_returns_default_when_no_file() {
        // In test environment, %APPDATA%/ipa-keyboard/ likely doesn't exist
        let config = load_config();
        assert!(config.cycle_timeout_ms > 0);
        assert!(!config.mappings.is_empty());
    }
}
