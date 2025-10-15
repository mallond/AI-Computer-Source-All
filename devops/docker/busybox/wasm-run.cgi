#!/usr/bin/env bash
set -euo pipefail

: "${INSTALL_DIR:=/opt/wasm-cgi}"
: "${WASM_DIR:=$INSTALL_DIR/www/cgi-bin/modules}"
: "${WASMTIME_BIN:=$INSTALL_DIR/bin/wasmtime}"
: "${LOG_DIR:=$INSTALL_DIR/logs}"

mkdir -p "$LOG_DIR"
log_file="${LOG_DIR}/wasm-cgi-$(date +%F).log"
touch "$log_file" || true

# lightweight request id
reqid="$(date +%s)-$$-$(printf %04x $RANDOM)"

log_kv () {
  # ts  reqid  remote  method  script  request_uri  path_info  query
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -Iseconds)" \
    "$reqid" \
    "${REMOTE_ADDR:-?}" \
    "${REQUEST_METHOD:-?}" \
    "${SCRIPT_NAME:-?}" \
    "${REQUEST_URI:-?}" \
    "${PATH_INFO:-}" \
    "${QUERY_STRING:-}" >> "$log_file"
}

# Resolve module name from PATH_INFO or ?module=
modname=""
if [ -n "${PATH_INFO:-}" ]; then
  modname="${PATH_INFO%%\?*}"
  modname="$(basename "$modname")"
elif [ -n "${QUERY_STRING:-}" ]; then
  IFS='&' read -r -a pairs <<'QSEND'
'"${QUERY_STRING}"'
QSEND
  for kv in "${pairs[@]}"; do
    case "$kv" in
      module=*) modname="${kv#module=}"; break ;;
    esac
  done
fi

log_kv

if [ -z "$modname" ]; then
  echo "Status: 400 Bad Request"
  echo "X-Request-Id: $reqid"
  echo "Content-Type: text/plain"; echo
  echo "Usage:"
  echo "  /cgi-bin/wasm-run.cgi/hello.wasm"
  echo "  /cgi-bin/wasm-run.cgi?module=hello.wasm"
  printf '[warn] %s missing module name\n' "$reqid" >> "$log_file"
  exit 0
fi

module="$WASM_DIR/$modname"
if [ ! -f "$module" ]; then
  echo "Status: 404 Not Found"
  echo "X-Request-Id: $reqid"
  echo "Content-Type: text/plain"; echo
  echo "Module not found: $modname"
  printf '[err] %s module not found: %s\n' "$reqid" "$module" >> "$log_file"
  exit 0
fi

printf '--- begin run %s %s ---\n' "$reqid" "$module" >> "$log_file"

echo "Status: 200 OK"
echo "X-Request-Id: $reqid"
echo "Content-Type: text/plain"
echo

set +e
"$WASMTIME_BIN" --dir "$WASM_DIR" "$module" \
  2> >(tee -a "$log_file" >&2) | tee -a "$log_file"
rc=$?
set -e

printf '\n[exit=%d] %s\n' "$rc" "$reqid" >> "$log_file"
exit 0
