# Connect IQ builder + simulator environment.
# Base must ship libwebkit2gtk-4.0 for the simulator: ubuntu:22.04 does,
# 24.04 does not. Never bump without checking (see agent_docs/gotchas.md).
FROM ubuntu:22.04

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=developer

# ARG (not ENV) so it applies to build-time apt only, not the runtime env.
# Without it any package whose postinst asks a debconf question (tzdata)
# hangs the build forever at an invisible prompt.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# UTF-8 locale (C.utf8 ships with glibc, no locales package needed). Without
# it the simulator's device-window title (non-ASCII device names) fails
# UTF8->ASCII conversion in xprop/xwininfo and the screenshot window lookup
# silently grabs the wrong window.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# System dependencies (headless build tier)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    dnsutils \
    fd-find \
    git \
    htop \
    iputils-ping \
    jq \
    libxml2-utils \
    make \
    nano \
    openjdk-17-jre-headless \
    openssl \
    procps \
    python3 \
    ripgrep \
    tree \
    unzip \
    vim \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s $(which fdfind) /usr/local/bin/fd

# Go toolchain (jammy's apt golang is too old for the SDK manager CLI)
RUN GO_VER="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)" \
    && ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL "https://go.dev/dl/${GO_VER}.linux-${ARCH}.tar.gz" \
       | tar -C /usr/local -xz
ENV PATH=/usr/local/go/bin:${PATH}

# Simulator + screenshot stack. The simulator's direct deps (objdump -p:
# webkit2gtk-4.0, gtk3, libsecret, libusb, libsm, libxxf86vm, libxkbcommon)
# plus a headless X stack (xvfb + openbox: bare Xvfb has no WM, and the
# screenshot flow finds the sim window via _NET_CLIENT_LIST, which only a WM
# populates), xprop (x11-utils), IM6 import (imagemagick), ss (iproute2),
# software GL, fonts, dbus.
RUN apt-get update && apt-get install -y \
    dbus-x11 \
    fonts-dejavu-core \
    imagemagick \
    iproute2 \
    libgl1-mesa-dri \
    libgtk-3-0 \
    libsecret-1-0 \
    libsm6 \
    libusb-1.0-0 \
    libwebkit2gtk-4.0-37 \
    libxkbcommon0 \
    libxxf86vm1 \
    novnc \
    openbox \
    websockify \
    x11-utils \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# ImageMagick 7: the screenshot scripts call `magick`, which apt's IM6
# does not provide. Official AppImage from the latest GitHub release
# (x86_64 only), extracted so no FUSE is needed.
RUN URL="$(curl -fsSL https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest \
        | jq -r '.assets[].browser_download_url | select(endswith("gcc-x86_64.AppImage"))')" \
    && curl -fsSL "$URL" -o /tmp/magick \
    && chmod +x /tmp/magick \
    && cd /opt \
    && /tmp/magick --appimage-extract >/dev/null \
    && mv squashfs-root magick \
    && chmod -R a+rX magick \
    && ln -s /opt/magick/AppRun /usr/local/bin/magick \
    && rm /tmp/magick

# Create user matching host UID/GID. The username must be the host username so
# the container home equals the host home path: project Makefiles and the SDK
# manager CLI config use absolute $HOME paths (see CLAUDE.md invariants).
RUN existing_user=$(getent passwd ${USER_ID} | cut -d: -f1) \
    && [ -n "$existing_user" ] && userdel -r "$existing_user" 2>/dev/null || true \
    && existing_group=$(getent group ${GROUP_ID} | cut -d: -f1) \
    && [ -n "$existing_group" ] && groupmod -n ${USERNAME} "$existing_group" || groupadd -g ${GROUP_ID} ${USERNAME} \
    && useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash ${USERNAME}

USER ${USERNAME}
ENV PATH=/home/${USERNAME}/go/bin:${PATH}

# SDK manager CLI into $HOME/go/bin, where project Makefiles expect it.
# Image layer, not a mount: only ~/.Garmin and ~/.connect-iq-sdk-manager are
# mounted, $HOME itself is not.
RUN go install github.com/lindell/connect-iq-sdk-manager-cli@latest

# Scripts last: editing them must not invalidate the layers above.
# COPY ownership defaults to root regardless of USER; exec bits come from the
# repo. garmin-setup and verify-connectiq are commands, so they drop the .sh.
# monkeyc/monkeydo/simulator are sdk-tool symlinks so docker exec (which
# bypasses login shells and their SDK PATH) still resolves them; profile.sh
# recreates the entrypoint env for `docker exec ... bash -l` shells.
COPY scripts/container/ /usr/local/bin/
USER root
RUN cd /usr/local/bin \
    && mv garmin-setup.sh garmin-setup \
    && mv verify-connectiq.sh verify-connectiq \
    && mv profile.sh /etc/profile.d/garmin-dev.sh \
    && ln -s sdk-tool monkeyc \
    && ln -s sdk-tool monkeydo \
    && ln -s sdk-tool simulator
USER ${USERNAME}

WORKDIR /home/${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
