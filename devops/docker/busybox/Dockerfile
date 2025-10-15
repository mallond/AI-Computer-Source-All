# Lighttpd + CGI + WASM (WASI) Hello World
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install web server + tools + wasm runtime & wat->wasm compiler
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      lighttpd bash ca-certificates wasmtime wabt \
 && rm -rf /var/lib/apt/lists/*

# Folders
RUN mkdir -p /var/www/html /var/www/cgi-bin /var/www/wasm

# Index page
RUN printf '%s\n' '\
<!doctype html><html><body>\
  <h1>WASM CGI POC</h1>\
  <ul>\
    <li><a href="/cgi-bin/hello-wasm.cgi">Direct: hello-wasm.cgi</a></li>\
    <li><a href="/cgi-bin/wasm-run.cgi/hello.wasm">PATH_INFO: wasm-run.cgi/hello.wasm</a></li>\
  </ul>\
  <p>Directory listings enabled: try <a href="/cgi-bin/">/cgi-bin/</a> and <a href="/wasm/">/wasm/</a></p>\
</body></html>' > /var/www/html/index.html

# --- Build a minimal WASI "Hello World" from WAT to WASM ---
# Writes to stdout via wasi fd_write.
RUN cat > /var/www/wasm/hello.wat <<'WAT'
(module
  (type $t0 (func (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (type $t0)))
  (memory 1)
  (export "memory" (memory 0))
  ;; buffer starts at 8; iovec at 0..7
  (data (i32.const 8) "Hello from WASM via CGI!\n")
  (func $_start (export "_start")
    ;; iovec.base = 8, iovec.len = 25
    (i32.store (i32.const 0) (i32.const 8))
    (i32.store (i32.const 4) (i32.const 25))
    (call $fd_write
      (i32.const 1)    ;; fd = 1 (stdout)
      (i32.const 0)    ;; &iovec
      (i32.const 1)    ;; iovec count
      (i32.const 100)  ;; &nwritten (unused)
    )
    drop
  )
)
WAT
RUN wat2wasm /var/www/wasm/hello.wat -o /var/www/wasm/hello.wasm

# --- CGI scripts ---
# Direct runner: fixed hello.wasm
RUN printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'echo "Content-Type: text/plain"' \
  'echo' \
  'export HOME=/tmp' \
  'exec wasmtime run -- /var/www/wasm/hello.wasm' \
  > /var/www/cgi-bin/hello-wasm.cgi \
 && chmod +x /var/www/cgi-bin/hello-wasm.cgi

# PATH_INFO-capable runner:
#   /cgi-bin/wasm-run.cgi/hello.wasm  -> runs /var/www/wasm/hello.wasm
RUN printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'echo "Content-Type: text/plain"' \
  'echo' \
  'export HOME=/tmp' \
  'WASM="/var/www/wasm/hello.wasm"' \
  'if [[ -n "${PATH_INFO:-}" ]]; then WASM="/var/www/wasm/${PATH_INFO#/}"; fi' \
  'if [[ ! -f "$WASM" ]]; then echo "wasm not found: $WASM"; exit 1; fi' \
  'exec wasmtime run -- "$WASM"' \
  > /var/www/cgi-bin/wasm-run.cgi \
 && chmod +x /var/www/cgi-bin/wasm-run.cgi

# Lighttpd config with CGI enabled on port 8090
RUN cat > /etc/lighttpd/lighttpd.conf <<'EOF'
server.document-root    = "/var/www/html"
server.port             = 8090
server.bind             = "0.0.0.0"

dir-listing.activate    = "enable"

server.modules += (
  "mod_alias",
  "mod_cgi",
  "mod_accesslog"
)

# Map /cgi-bin to our scripts
alias.url = (
  "/cgi-bin/" => "/var/www/cgi-bin/",
  "/wasm/"    => "/var/www/wasm/"
)

# Execute *.cgi with bash; allow PATH_INFO for scripts in /cgi-bin
$HTTP["url"] =~ "^/cgi-bin/" {
  cgi.assign = ( ".cgi" => "/bin/bash", ".sh" => "/bin/bash" )
  setenv.add-environment = ( "HOME" => "/tmp" )
}

# Logs to stderr for `docker logs`
accesslog.filename           = "/dev/stderr"
server.errorlog-use-syslog   = "disable"
server.errorlog              = "/dev/stderr"
EOF

EXPOSE 8090
CMD ["lighttpd","-D","-f","/etc/lighttpd/lighttpd.conf"]
