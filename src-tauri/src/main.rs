// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;

fn main() {
    let product_name = env!("PRODUCT_NAME");
    let version = env!("VERSION");
    
    println!("Starting {} v{}", product_name, version);
    
    tauri_app_lib::run();
}
