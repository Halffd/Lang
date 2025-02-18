use std::env;
use std::fs;
use std::path::Path;
use serde_json::Value;

fn main() {
    println!("cargo:rerun-if-changed=tauri.conf.json");
    
    // Read and parse the config file
    let config_path = Path::new("tauri.conf.json");
    let config_str = fs::read_to_string(config_path)
        .expect("Failed to read tauri.conf.json");
    let config: Value = serde_json::from_str(&config_str)
        .expect("Failed to parse tauri.conf.json");

    // Set up platform-specific configurations
    #[cfg(target_os = "windows")]
    println!("cargo:rustc-cfg=windows");
    #[cfg(target_os = "macos")]
    println!("cargo:rustc-cfg=macos");
    #[cfg(target_os = "linux")]
    println!("cargo:rustc-cfg=linux");
    
    // Set up desktop configuration
    println!("cargo:rustc-cfg=desktop");

    // Extract and set up environment variables from config
    if let Some(package) = config.get("package") {
        if let Some(product_name) = package.get("productName") {
            println!("cargo:rustc-env=PRODUCT_NAME={}", product_name.as_str().unwrap());
        }
        if let Some(version) = package.get("version") {
            println!("cargo:rustc-env=VERSION={}", version.as_str().unwrap());
        }
    }

    // Set up development mode flag
    if env::var("PROFILE").unwrap() == "debug" {
        println!("cargo:rustc-cfg=dev");
    }

    // Handle custom protocol feature
    if env::var_os("CARGO_FEATURE_CUSTOM_PROTOCOL").is_some() {
        println!("cargo:rustc-cfg=custom_protocol");
    }
}
