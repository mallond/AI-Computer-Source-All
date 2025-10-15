# Build
docker build -t wasm-cgi:latest .

# Run (default MODE=simple, port 8080)
docker run --rm -p 8090:8080 \
  -e MODE=simple \
  -v "$(pwd)/modules:/opt/wasm-cgi/www/cgi-bin/modules" \
  wasm-cgi:latest
