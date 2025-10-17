1) Install the WASM target
rustup target add wasm32-unknown-unknown

2) (Recommended for browser) Install helpers
cargo install wasm-bindgen-cli          # generates JS bindings
# optional but great for size/speed:
# brew install binaryen   # macOS (or your package manager)
# wasm-opt --version      # from binaryen


Alternative one-stop tool: cargo install wasm-pack (then use wasm-pack build instead of the manual bindgen step below).

3) Set up your crate for WASM

If you’re building for the browser, make (or add) a library target and mark it as a cdylib so it links to .wasm cleanly.

Cargo.toml

[package]
name = "your_crate"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"

[profile.release]
lto = true
opt-level = "z"
codegen-units = 1


wasmtime target/wasm32-wasip1/release/cargo.wasm
# or: wasmer run ...
