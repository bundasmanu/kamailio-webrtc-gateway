FROM debian:trixie-20260112-slim as webrtc-gateway

ARG KAMAILIO_VERSION
ARG STARTER_KAM_USER
ARG STARTER_KAM_GROUP
ARG CONFIGS_FOLDER

WORKDIR /root

## install some dependencies
RUN apt update && \
    apt install -y wget \
    gnupg2 \
    sngrep \
    sipsak \
    curl \
    vim \
    sudo \
    lsb-release

RUN curl -s https://packagecloud.io/install/repositories/gustavo/kamailio/script.deb.sh | bash

## install package
##RUN wget -qO- https://deb.kamailio.org/kamailiodebkey.gpg | gpg --dearmor 2>/dev/null | tee /usr/share/keyrings/kamailio.gpg >/dev/null && \
    ##echo "deb [signed-by=/usr/share/keyrings/kamailio.gpg] http://deb.kamailio.org/kamailio${KAMAILIO_VERSION} $(lsb_release -cs) main" > /etc/apt/sources.list.d/kamailio.list && \
    ##apt update

## create user and group, if not root
RUN USER=$(echo "$STARTER_KAM_USER" | tr '[:upper:]' '[:lower:]') && \
    GROUP=$(echo "$STARTER_KAM_GROUP" | tr '[:upper:]' '[:lower:]') && \
    if [ "$GROUP" != "root" ] && ! getent group "$GROUP" > /dev/null; then groupadd "$GROUP"; fi && \
    if [ "$GROUP" != "root" ] && ! id "$USER" > /dev/null 2>&1; then useradd -m -g "$GROUP" "$USER"; fi

## get packages to be installed
RUN apt install -y kamailio \
        kamailio-postgres-modules \
        kamailio-tls-modules \
        kamailio-json-modules \
        kamailio-extra-modules \
        kamailio-utils-modules \
        kamailio-outbound-modules \
        kamailio-websocket-modules

COPY configs ${CONFIGS_FOLDER}

WORKDIR /etc/kamailio

COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
CMD ["test-version"]
