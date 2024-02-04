FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# these are specified in Makefile
ARG ARCH
ARG PLATFORM
ARG SPARROW_VERSION
ARG SPARROW_DEBVERSION
ARG SPARROW_PGP_SIG
ARG YQ_VERSION
ARG YQ_SHA

RUN \
  echo "**** install packages ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
    exo-utils \
    mousepad \
    xfce4-terminal \
    tumbler \
    thunar \
    python3-xdg \
    wget \
    socat \
    gnupg && \
  wget -qO /tmp/yq https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${PLATFORM} && \
  echo "${YQ_SHA} /tmp/yq" | sha256sum --check || exit 1 && \ 
  mv /tmp/yq /usr/local/bin/yq && chmod +x /usr/local/bin/yq && \
  echo "**** xfce tweaks ****" && \
  rm -f /etc/xdg/autostart/xscreensaver.desktop && \
  sed -i 's|</applications>|  <application title="Sparrow" type="normal">\n    <maximized>yes</maximized>\n  </application>\n</applications>|' /etc/xdg/openbox/rc.xml && \
  # StartOS branding
  echo "Starting Sparrow on Webtop for StartOS..." > /etc/s6-overlay/s6-rc.d/init-adduser/branding; sed -i '/run_branding() {/,/}/d' /docker-mods && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# Sparrow
RUN \
  echo "**** install Sparrow ****" && \
  # sparrow requires this directory to exist
  mkdir -p /usr/share/desktop-directories/ && \
  # Download and install Sparrow (todo: gpg sig verification)
  wget --quiet https://github.com/sparrowwallet/sparrow/releases/download/${SPARROW_VERSION}/sparrow_${SPARROW_DEBVERSION}_${PLATFORM}.deb \
                https://github.com/sparrowwallet/sparrow/releases/download/${SPARROW_VERSION}/sparrow-${SPARROW_VERSION}-manifest.txt \
                https://github.com/sparrowwallet/sparrow/releases/download/${SPARROW_VERSION}/sparrow-${SPARROW_VERSION}-manifest.txt.asc \
                https://keybase.io/craigraw/pgp_keys.asc && \
  # verify pgp and sha signatures
  gpg --import pgp_keys.asc && \
  gpg --status-fd 1 --verify sparrow-${SPARROW_VERSION}-manifest.txt.asc | grep -q "GOODSIG ${PGP_SIG}" || exit 1 && \
  sha256sum --check sparrow-${SPARROW_VERSION}-manifest.txt --ignore-missing || exit 1 && \
  apt-get install -y ./sparrow_${SPARROW_DEBVERSION}_${PLATFORM}.deb && \
  # cleanup
  rm ./sparrow* ./pgp_keys.asc

# add local files
COPY /root /
COPY --chmod=a+x ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY --chmod=664 icon.png /kclient/public/icon.png
COPY --chmod=664 icon.png /kclient/public/favicon.ico

# ports and volumes
EXPOSE 3000
VOLUME /config
