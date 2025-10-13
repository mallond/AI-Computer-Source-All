FROM ghcr.io/coder/code-server:4.104.3

USER root
RUN apt-get update && apt-get install -y \
    git curl bash-completion build-essential ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /workspace && chown -R coder:coder /workspace
USER coder

# Optional extensions
RUN code-server --install-extension esbenp.prettier-vscode || true
RUN code-server --install-extension ms-vscode.vscode-typescript-next || true

WORKDIR /workspace
EXPOSE 8080

