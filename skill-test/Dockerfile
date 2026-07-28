ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    ripgrep \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

RUN useradd --create-home --shell /bin/bash claude \
  && mkdir -p /workspace /runs \
  && chown -R claude:claude /workspace /runs

COPY container/run-claude-prompt.sh /usr/local/bin/run-claude-prompt
COPY container/run-claude-session.sh /usr/local/bin/run-claude-session
RUN chmod +x /usr/local/bin/run-claude-prompt /usr/local/bin/run-claude-session

USER claude
ENV HOME=/home/claude
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "--version"]
