FROM ubuntu:25.10
# It is relatively straightforward to change to Debian/Kali. Been there, done that, got the T-Shirt.
# Not going back, most 3rd party apps only support Ubuntu out of the box and my time is valuable.
# do not change USER_UID/USER_GUID since plenty of badly written docker/container software only works with UID 1000. Sigh.
ENV USER_UID=1000
ENV USER_GID=$USER_UID
# docker uses "sh" by default, we want bash, since we need some buildin commands which might not not be buildin with lesser shells.
SHELL ["/bin/bash", "-c"]
# Please refer to the README.md. Baldwin is a character (the "ass" aka donkey) in the medieval fable of Reynard the Fox.
ENV USER_NAME=baldwin

# TODO move this to separate file and use awk/xargs (standard install for Ubuntu and others ??)
# xargs -a <(awk '! /^ *(#|$)/' "$packagelist") -r -- sudo apt-get -y install --no-install-recommends
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update && apt-get -y install --no-install-recommends \
      7zip \
      asciinema \
      bats \
      bc \
      build-essential \
      ca-certificates \
      cloc \
      coreutils \
      cron \
      curl \
      dialog \
      dirmngr \
      dnsutils \
      dos2unix \
      dotnet-sdk-9.0 \
      fuse-overlayfs \
      gawk \
      git \
      gnupg2 \
      golang \
      jq \
      just \
      lsb-release \
      locales \
      make \
      nano \
      net-tools \
      passt \
      pipx \
      pigz \
      pkg-config \
      pre-commit \
      python3 \
      python3-pip \
      python3-setuptools \
      python3-venv \
      ripgrep \
      slirp4netns \
      tar \
      shellcheck \
      sudo \
      tree \
      uidmap \
      unzip \
      wget \
      yq \
      zip

# Fixing locales. Do not remove, you will run into problems with certain distros/images.
RUN command -v locale-gen &>/dev/null && \
    locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && export LANGUAGE=en_US.UTF-8 \
    && export LANG=en_US.UTF-8 \
    && export LC_ALL=en_US.UTF-8

# Installing nodejs/npm/pnpm
RUN curl -fsSL https://deb.nodesource.com/setup_24.x -o nodesource_setup.sh \
    && bash ./nodesource_setup.sh \
    && rm -rf ./nodesource_setup.sh \
    && export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -y install --no-install-recommends nodejs \
    && npm install -g pnpm

# Install opengrep
RUN og_version=$(curl -s https://api.github.com/repos/opengrep/opengrep/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') \
    && if [[ -n "$og_version" && "$arch" == *arm* ]] ; \
       then wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_aarch64 ; \
       else wget --quiet --output-document /usr/local/bin/opengrep https://github.com/opengrep/opengrep/releases/download/"$og_version"/opengrep_manylinux_x86 ; \
       fi && sudo chmod a+x /usr/local/bin/opengrep || true

# Installing Docker
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
    && apt-get -y install --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

# Delete default "ubuntu/vscode" user, if it exists. Be in control.
# TODO find and wipe all "default" users. How?
RUN if id "ubuntu" &>/dev/null; then deluser --remove-home ubuntu; fi
RUN if id "vcode" &>/dev/null; then deluser --remove-home vscode; fi

# Create the user, add to docker group
RUN groupadd --non-unique --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID --gid $USER_GID -c "Account created by `baldwin`" -s /usr/bin/bash -m $USER_NAME \
    && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME \
    && getent group docker &>/dev/null|| groupadd docker \
    && usermod -aG docker $USER_NAME

# Cleanup -> not really needed, since we install more apps in postCreateCommand.sh
# RUN rm -rf /var/lib/apt/lists/*

# Set the default user. Run whatever you need to install as non-root user after this line.
ENV HOME /home/$USER_NAME
USER $USER_NAME
WORKDIR $HOME
