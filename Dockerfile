# Base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    gnupg \
    git \
    dnsutils \
    postgresql-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu
RUN apt-get update && apt-get install curl -y && curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && chmod +x install-opentofu.sh && ./install-opentofu.sh --install-method deb && rm -f install-opentofu.sh
ARG DOCTL_VERSION=1.109.0
RUN curl -sL https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-1.109.0-linux-amd64.tar.gz -o doctl.tar.gz && \
    tar -xzf doctl.tar.gz && \
    mv doctl /usr/local/bin/doctl && \
    chmod +x /usr/local/bin/doctl && \
    rm doctl.tar.gz

# Working directory where project gets mounted
WORKDIR /app

# Add entrypoint
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
