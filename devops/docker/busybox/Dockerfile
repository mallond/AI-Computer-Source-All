# ---- Build stage: compile Rust binary ----------------------------------------
FROM rust:1.81-bookworm AS builder
WORKDIR /build

# Cache dependencies first for faster rebuilds
COPY Cargo.toml Cargo.lock* ./
RUN mkdir -p src && echo 'fn main(){ println!("CGI build warmup"); }' > src/main.rs \
 && cargo build --release || true

# Real sources
RUN rm -rf src
COPY . .

# Install the compiled binary into /out/bin/<your-binary-name>
RUN cargo install --path . --root /out

# ---- Runtime stage: lighttpd + CGI wrapper ----------------------------------
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends lighttpd bash ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Web roots
RUN mkdir -p /var/www/html /var/www/cgi-bin

# Copy compiled Rust binary/binaries
COPY --from=builder /out/bin /opt/rust-bin
RUN chmod -R 0755 /opt/rust-bin

# --- CGI wrapper ---
# This wrapper finds the first installed Rust binary and executes it.
# If the program doesn't print a CGI header, we add a default text/plain header.
RUN printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'BIN="$(find /opt/rust-bin -maxdepth 1 -type f -executable | head -n1)"' \
  'if [[ -z "${BIN}" ]]; then echo "Content-Type: text/plain"; echo; echo "No Rust CGI binary found in /opt/rust-bin"; exit 1; fi' \
  'TMP="$(mktemp)"' \
  '"${BIN}" >"$TMP" 2>&1 || true' \
  'if head -n1 "$TMP" | grep -qi "^Content-Type:"; then' \
  '  cat "$TMP"' \
  'else' \
  '  echo "Content-Type: text/plain"' \
  '  echo' \
  '  cat "$TMP"' \
  'fi' \
  'rm -f "$TMP"' \
  > /var/www/cgi-bin/rust-app.cgi \
 && chmod +x /var/www/cgi-bin/rust-app.cgi

# Simple index page
RUN printf '%s\n' '\
<!doctype html><html><body>\
<h1>Rust CGI via lighttpd</h1>\
<ul><li><a href="/cgi-bin/rust-app.cgi">Run CGI</a></li></ul>\
</body></html>' > /var/www/html/index.html

# Lighttpd config (port 8090 + CGI enabled)
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

# Map /cgi-bin and execute *.cgi via bash
alias.url = ( "/cgi-bin/" => "/var/www/cgi-bin/" )
$HTTP["url"] =~ "^/cgi-bin/" {
  cgi.assign = ( ".cgi" => "/bin/bash" )
  setenv.add-environment = ( "HOME" => "/tmp" )
}

# Log to stderr for `docker logs`
accesslog.filename           = "/dev/stderr"
server.errorlog-use-syslog   = "disable"
server.errorlog              = "/dev/stderr"
EOF

EXPOSE 8090
CMD ["lighttpd","-D","-f","/etc/lighttpd/lighttpd.conf"]
