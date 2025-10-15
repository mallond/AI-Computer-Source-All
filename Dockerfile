# ---- Build a tiny Rust/WASI module that prints "Hello Pinky!" ----
FROM rust:1.81-bookworm AS builder
RUN rustup target add wasm32-wasi
WORKDIR /app/hello
RUN set -eux; \
    mkdir -p src; \
    printf '%s\n' \
      '[package]' \
      'name = "hello"' \
      'version = "0.1.0"' \
      'edition = "2021"' \
      '' \
      '[dependencies]' \
      > Cargo.toml; \
    printf '%s\n' \
      'fn main() {' \
      '    println!("Hello Pinky!");' \
      '}' \
      > src/main.rs; \
    cargo build --release --target wasm32-wasi
# Result: /app/hello/target/wasm32-wasi/release/hello.wasm


# ---- Runtime image: BusyBox httpd + Wasmtime (WASI) ----
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG WASMTIME_VERSION=25.0.0

# BusyBox httpd + curl + certs + xz (to extract .tar.xz)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl busybox-static xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Layout / config
ENV INSTALL_DIR=/opt/wasm-cgi \
    PORT=8080 \
    MODE=simple
RUN mkdir -p ${INSTALL_DIR}/bin ${INSTALL_DIR}/www/cgi-bin/modules

# Install Wasmtime (asset: wasmtime-v${ver}-${arch}-linux.tar.xz)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) wt_arch="x86_64" ;; \
      arm64) wt_arch="aarch64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}"; \
    tarball="wasmtime-v${WASMTIME_VERSION}-${wt_arch}-linux.tar.xz"; \
    tmp="$(mktemp -d)"; \
    curl -fL "${base}/${tarball}" -o "${tmp}/w.txz"; \
    tar -C "${tmp}" -xJf "${tmp}/w.txz"; \
    cp "${tmp}/wasmtime-v${WASMTIME_VERSION}-${wt_arch}-linux/wasmtime" "${INSTALL_DIR}/bin/wasmtime"; \
    chmod +x "${INSTALL_DIR}/bin/wasmtime"; \
    rm -rf "${tmp}"

# Minimal CGI wrapper (always injects text/plain header, runs module)
RUN cat > "${INSTALL_DIR}/www/cgi-bin/wasm-run.cgi" <<'EOF' \
 && chmod +x "${INSTALL_DIR}/www/cgi-bin/wasm-run.cgi"
#!/usr/bin/env bash
set -euo pipefail
: "${INSTALL_DIR:=/opt/wasm-cgi}"
: "${WASM_DIR:=$INSTALL_DIR/www/cgi-bin/modules}"
: "${WASMTIME_BIN:=$INSTALL_DIR/bin/wasmtime}"

# module name comes from PATH_INFO (/cgi-bin/wasm-run.cgi/hello.wasm)
modname="$(basename "${PATH_INFO:-}")"
modname="${modname%%\?*}"

if [ -z "$modname" ]; then
  echo "Status: 400 Bad Request"
  echo "Content-Type: text/plain"; echo
  echo "Usage: /cgi-bin/wasm-run.cgi/hello.wasm"
  exit 0
fi

module="$WASM_DIR/$modname"
[ -f "$module" ] || { echo "Status: 404 Not Found"; echo "Content-Type: text/plain"; echo; echo "Module not found: $modname"; exit 0; }

echo "Status: 200 OK"
echo "Content-Type: text/plain"
echo
EOF

# Tiny index
RUN cat > "${INSTALL_DIR}/www/index.html" <<'EOF'
<!doctype html><meta charset="utf-8">
<body style="font-family: system-ui; padding:1rem">
<h1>WASM as CGI</h1>
<p>Open: <code>/cgi-bin/wasm-run.cgi/hello.wasm</code></p>
</body>
EOF

# Copy the sample WASM
COPY --from=builder /app/hello/target/wasm32-wasi/release/hello.wasm ${INSTALL_DIR}/www/cgi-bin/modules/hello.wasm


# Create a home that is writable by 'wasm' and precreate cache dir
RUN useradd -m -r -u 10001 -g nogroup wasm \
 && mkdir -p /home/wasm/.cache/wasmtime \
 && chown -R wasm:nogroup /home/wasm
USER wasm
WORKDIR ${INSTALL_DIR}/www
EXPOSE 8080
CMD ["/bin/busybox", "httpd", "-f", "-p", "8080", "-h", "/opt/wasm-cgi/www"]
