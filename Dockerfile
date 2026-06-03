# Image reproductible de l'agent de revue Pulse.
# Reproductibilité : base épinglée + version du paquet épinglée (build-arg).
# Hygiène du secret : AUCUNE clé n'est copiée ni passée en ARG ; ANTHROPIC_API_KEY
# est injectée uniquement au RUNTIME (docker run -e ANTHROPIC_API_KEY ...).
FROM node:20-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq python3 git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Épingler à une version fixe pour une image reproductible :
#   docker build --build-arg CLAUDE_CODE_VERSION=<x.y.z> .
ARG CLAUDE_CODE_VERSION=latest
ENV CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /agent
COPY agent/ /agent/
RUN chmod +x /agent/review.sh

# Pas d'ANTHROPIC_API_KEY ici : la clé arrive au runtime via -e.
ENV OUT_DIR=/work
ENTRYPOINT ["/agent/review.sh"]
