# Build
docker build -t wasm-cgi:hello-pinky .

# Run (default MODE=simple, port 8080)
docker run -d --name wasm-cgi -p 8090:8080 wasm-cgi:hello-pinky


# WASM as CGI with BusyBox httpd + Wasmtime

Run tiny **Rust/WASI** programs as classic **CGI** endpoints—inside a minimal Docker image powered by **BusyBox httpd** and **Wasmtime**.

This repo folder contains a single Dockerfile that:

* Builds a Rust “Hello Pinky!” WASI module.
* Serves it via BusyBox httpd.
* Executes the module through Wasmtime when you hit a CGI route.

---

## Why this exists

**WASM (WASI) as server-side CGI** gives you:

* **Portability:** Compile-once, run anywhere with a WASI runtime.
* **Security:** Unprivileged user, no shelling out, limited FS access, sandbox via Wasmtime.
* **Simplicity:** No frameworks—just HTTP server + CGI runner.
* **Tiny surface area:** Great for demos, teaching, or micro-utilities.

---

## What’s inside

* **Rust/WASI example:** A tiny program printing `Hello Pinky!`
* **CGI wrapper:** A POSIX sh script that:

  * Parses module name from `PATH_INFO` or `REQUEST_URI`
  * Emits HTTP headers
  * Runs the WASI module via `wasmtime run`
* **Minimal server:** BusyBox `httpd` in foreground + verbose mode
* **Non-root user:** `wasm` with a writable Wasmtime cache

---

## Quick start

```bash
# From the Docker folder (this README’s context)
docker build -t wasm-cgi-hello .

docker run --rm -p 8080:8080 --name wasm-cgi wasm-cgi-hello
```

Open:

```
http://localhost:8080/cgi-bin/wasm-run.cgi/hello.wasm
```

Or curl:

```bash
curl -s http://localhost:8080/cgi-bin/wasm-run.cgi/hello.wasm
# => Hello Pinky!
```

---

## Directory layout (in container)

```
/opt/wasm-cgi/
├─ bin/
│  └─ wasmtime
└─ www/
   ├─ index.html
   └─ cgi-bin/
      ├─ wasm-run.cgi            # CGI wrapper (POSIX sh)
      └─ modules/
         └─ hello.wasm           # Built Rust/WASI sample
```

---

## Request flow

1. **BusyBox httpd** receives `GET /cgi-bin/wasm-run.cgi/hello.wasm`.
2. **CGI wrapper** resolves the module name (`hello.wasm`), writes headers.
3. **Wasmtime** executes the module (`wasmtime run modules/hello.wasm`).
4. **stdout from the WASI program** becomes the HTTP response body.

---

## Environment variables

* `INSTALL_DIR` – root install dir (default `/opt/wasm-cgi`)
* `PORT` – httpd port (default `8080`)
* `WASMTIME_CACHE_DIR` – Wasmtime cache (default `/home/wasm/.cache/wasmtime`)

---

## Dockerfile breakdown (annotated)

```dockerfile
# Stage 1: Build a WASI module in Rust
FROM rust:1.81-bookworm AS builder
RUN rustup target add wasm32-wasi
WORKDIR /app/hello

# Create minimal Rust project that prints "Hello Pinky!"
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
# -> hello.wasm artifact lives at:
# /app/hello/target/wasm32-wasi/release/hello.wasm
```

**Why:** Keep the runtime image slim and clean. The entire Rust toolchain stays in the builder layer.

```dockerfile
# Stage 2: Runtime (BusyBox httpd + Wasmtime)
FROM debian:bookworm-slim

ARG WASMTIME_VERSION=25.0.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl busybox-static xz-utils \
 && rm -rf /var/lib/apt/lists/*
```

**Why:**

* `busybox-static` provides `httpd`, `sh`, and CGI support with minimal deps.
* `xz-utils` and `curl` are used to fetch/extract Wasmtime.

```dockerfile
# Dir layout + defaults
ENV INSTALL_DIR=/opt/wasm-cgi \
    PORT=8080 \
    MODE=simple \
    WASMTIME_CACHE_DIR=/home/wasm/.cache/wasmtime
RUN mkdir -p ${INSTALL_DIR}/bin ${INSTALL_DIR}/www/cgi-bin/modules
```

**Why:** Centralized paths make the wrapper/documentation predictable; setting cache keeps wasmtime happy without root access.

```dockerfile
# Install Wasmtime CLI (no package manager lock-in)
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
    curl -fsSL "${base}/${tarball}" -o "${tmp}/w.txz"; \
    tar -C "${tmp}" -xJf "${tmp}/w.txz"; \
    cp "${tmp}/wasmtime-v${WASMTIME_VERSION}-${wt_arch}-linux/wasmtime" "${INSTALL_DIR}/bin/wasmtime"; \
    chmod +x "${INSTALL_DIR}/bin/wasmtime"; \
    rm -rf "${tmp}"
```

**Why:** Direct, reproducible install of a specific Wasmtime version.

```dockerfile
# CGI wrapper: emits headers, resolves module, executes wasmtime
RUN cat > "${INSTALL_DIR}/www/cgi-bin/wasm-run.cgi" <<'EOF' \
 && chmod +x "${INSTALL_DIR}/www/cgi-bin/wasm-run.cgi"
#!/bin/sh
set -eu
: "${INSTALL_DIR:=/opt/wasm-cgi}"
: "${WASM_DIR:=$INSTALL_DIR/www/cgi-bin/modules}"
: "${WASMTIME_BIN:=$INSTALL_DIR/bin/wasmtime}"
: "${WASMTIME_CACHE_DIR:=/home/wasm/.cache/wasmtime}"

# Prefer PATH_INFO; fallback to REQUEST_URI
modname=""
if [ -n "${PATH_INFO:-}" ]; then
  modname=$(basename "$PATH_INFO")
else
  uri="${REQUEST_URI:-}"
  case "$uri" in *\?*) uri="${uri%%\?*}";; esac
  modname=$(basename "$uri")
fi

if [ -z "$modname" ]; then
  echo "Status: 400 Bad Request"
  echo "Content-Type: text/plain"; echo
  echo "Usage: /cgi-bin/wasm-run.cgi/hello.wasm"
  exit 0
fi

module="$WASM_DIR/$modname"
if [ ! -f "$module" ]; then
  echo "Status: 404 Not Found"
  echo "Content-Type: text/plain"; echo
  echo "Module not found: $modname"
  exit 0
fi

echo "Status: 200 OK"
echo "Content-Type: text/plain"
echo

exec "$WASMTIME_BIN" run "$module"
EOF
```

**Why:**

* Uses `/bin/sh` (BusyBox-compatible).
* Handles both `PATH_INFO` and `REQUEST_URI` so it works across httpd quirks.
* Uses `exec wasmtime run` so the module’s stdout becomes the response body.

```dockerfile
# Basic index for convenience
RUN cat > "${INSTALL_DIR}/www/index.html" <<'EOF'
<!doctype html><meta charset="utf-8">
<body style="font-family: system-ui; padding:1rem">
  <h1>WASM as CGI</h1>
  <p>Try: <a href="/cgi-bin/wasm-run.cgi/hello.wasm"><code>/cgi-bin/wasm-run.cgi/hello.wasm</code></a></p>
</body>
EOF
```

```dockerfile
# Bring in the built module
COPY --from=builder /app/hello/target/wasm32-wasi/release/hello.wasm ${INSTALL_DIR}/www/cgi-bin/modules/hello.wasm
```

```dockerfile
# Run as unprivileged user with a writable Wasmtime cache
RUN useradd -m -r -u 10001 -g nogroup wasm \
 && mkdir -p /home/wasm/.cache/wasmtime \
 && chown -R wasm:nogroup /home/wasm
USER wasm

WORKDIR ${INSTALL_DIR}/www
EXPOSE 8080

# Foreground + verbose to see CGI stderr in logs
CMD ["/bin/busybox", "httpd", "-f", "-v", "-p", "8080", "-h", "/opt/wasm-cgi/www"]
```

**Why:**

* Non-root `wasm` user for safety.
* Precreate cache to prevent Wasmtime permission errors.
* `-v` helps debug CGI issues quickly.

---

## Add more modules

Drop extra `.wasm` files into:

```
/opt/wasm-cgi/www/cgi-bin/modules/
```

Then call:

```
/cgi-bin/wasm-run.cgi/<your-module>.wasm
```

---

## Extending (handy patterns)

* **Pass args:**
  Modify the CGI to append `-- "$QUERY_STRING"` or parse key/values and pass as args.

* **Pass env vars to the WASI module:**

  ```
  wasmtime run --env REQUEST_METHOD="$REQUEST_METHOD" --env QUERY_STRING="$QUERY_STRING" "$module"
  ```

* **Preopen dirs/files (WASI I/O):**

  ```
  wasmtime run --dir /tmp "$module"
  ```

* **Better error handling:**
  Capture exit codes; on non-zero, emit `Status: 500` and log stderr.

* **Harden the container (compose or run flags):**

  * `--read-only` root FS
  * tmpfs for cache dir
  * `--cap-drop=ALL`
  * `--security-opt=no-new-privileges`

---

## Troubleshooting

* **Blank response?** Ensure the CGI wrapper executes `wasmtime`. Check logs (`httpd -v` already enabled).
* **404 “Module not found”**: Verify the file name in `/cgi-bin/modules` matches the URL.
* **Wasmtime cache permission errors**: Confirm `WASMTIME_CACHE_DIR` exists and is owned by user `wasm`.

---

## License

MIT (or your preferred license—fill this in for your repo).

---

## Credits

* [BusyBox httpd] for a tiny, capable HTTP server.
* [Wasmtime] (Bytecode Alliance) for a fast, secure WASI runtime.
* Rust + WASI for simple, portable server-side modules.



