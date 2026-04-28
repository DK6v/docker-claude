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

RUN curl -fsSL https://get.docker.com -o get-docker.sh \
 && sh get-docker.sh \
 && rm get-docker.sh

RUN corepack enable yarn

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /docker
ENV PATH=$PATH:/docker

COPY ./entrypoint.sh / 
RUN chmod +x /entrypoint.sh

CMD [ "/bin/bash", "-i" ]
ENTRYPOINT [ "/entrypoint.sh" ]

