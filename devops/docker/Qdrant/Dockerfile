# syntax=docker/dockerfile:1
# Qdrant vector database — simple, local-friendly image
# Build args let you pin versions if you want: --build-arg QDRANT_TAG=v1.9.0
ARG QDRANT_IMAGE=qdrant/qdrant
ARG QDRANT_TAG=latest
FROM ${QDRANT_IMAGE}:${QDRANT_TAG}

# Expose REST (6333) and gRPC (6334)
EXPOSE 6333 6334

# Persist data & snapshots between runs
VOLUME ["/qdrant/storage", "/qdrant/snapshots"]

# Optional: drop in your own config later if needed
# COPY qdrant.yaml /qdrant/config/production.yaml

# Healthcheck (Qdrant returns JSON at /collections)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=5 \
  CMD wget -qO- http://127.0.0.1:6333/collections >/dev/null 2>&1 || exit 1
