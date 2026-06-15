# Ubuntu 24.04 base image for validating install.sh Linux path (normal user + root)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    sudo \
    ca-certificates \
    htop \
    jq \
    locales \
    file \
    procps \
    tree \
    unzip \
    vim \
    wget \
    zip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y time && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

COPY . /opt/dotfiles
RUN chown -R testuser:testuser /opt/dotfiles

USER testuser
WORKDIR /home/testuser

CMD ["/bin/bash"]
