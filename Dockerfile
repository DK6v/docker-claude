FROM node:20-slim

RUN apt-get update \
 && apt-get install -y \
    git \
    curl \
    wget \
    bash \
    make \
    jq \
    less \
    procps \
    openssh-client \
    postgresql-client \
    ripgrep \
    python3 \
    python3-pip \
    netcat-openbsd \
    iputils-ping \
    dnsutils \
 && rm -rf /var/lib/apt/lists/*

COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker

RUN corepack enable yarn

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /docker
ENV PATH=$PATH:/docker

COPY ./*.sh .
RUN chmod +x *.sh

CMD [ "sleep", "infinity" ]
ENTRYPOINT [ "/docker/entrypoint.sh" ]
