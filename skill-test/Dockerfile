ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

ARG CLAUDE_CODE_VERSION=latest
# Pinned, not "latest": the Codex CLI's flag surface was observed to change
# between patch releases during harness development (e.g. --ask-for-approval
# dropped in favor of --approve-for-me between 0.156.1 and 0.160.1). Floating
# on latest risks a run silently breaking on an unrelated rebuild.
ARG CODEX_VERSION=0.160.1

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
RUN npm install -g "@openai/codex@${CODEX_VERSION}"

RUN useradd --create-home --shell /bin/bash claude \
  && mkdir -p /workspace /runs \
  && chown -R claude:claude /workspace /runs

COPY container/run-claude-prompt.sh /usr/local/bin/run-claude-prompt
COPY container/run-claude-session.sh /usr/local/bin/run-claude-session
COPY container/run-codex-prompt.sh /usr/local/bin/run-codex-prompt
RUN chmod +x /usr/local/bin/run-claude-prompt /usr/local/bin/run-claude-session /usr/local/bin/run-codex-prompt

USER claude
ENV HOME=/home/claude
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "--version"]
