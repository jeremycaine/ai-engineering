ARG NODE_IMAGE=public.ecr.aws/docker/library/node:22-bookworm-slim
FROM ${NODE_IMAGE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git iproute2 jq python3 python-is-python3 \
 && rm -rf /var/lib/apt/lists/*

# The sandbox network policy allows only read requests to the npm registry,
# so the automatic audit request would be denied. Turn it off.
RUN npm config set audit false --global

RUN userdel -r node \
 && groupadd -g 1000 sandbox \
 && useradd -m -d /sandbox -u 1000 -g 1000 -s /bin/bash sandbox

USER sandbox
WORKDIR /sandbox
