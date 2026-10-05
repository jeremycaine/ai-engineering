ARG BASE_IMAGE=localhost/agent-sandbox-base:0.1
FROM ${BASE_IMAGE}

# Claude Code is proprietary software. Build this image on your own machine.
# Do not publish it. Use is subject to Anthropic's terms.
ARG CLAUDE_CODE_VERSION

USER root
RUN test -n "${CLAUDE_CODE_VERSION}" || { echo "Set --build-arg CLAUDE_CODE_VERSION=<version>" >&2; exit 1; }

# The project marks the npm install route as deprecated. If you change the route,
# the binary path in policies/fragments/20-agent-claude.yaml changes too.
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Turn off the self-update (the install folder is read-only for the sandbox user)
# and the non-essential traffic that the sandbox policy denies.
RUN mkdir -p /etc/claude-code \
 && printf '%s\n' '{"env":{"DISABLE_AUTOUPDATER":"1","CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"1"}}' > /etc/claude-code/managed-settings.json

USER sandbox
