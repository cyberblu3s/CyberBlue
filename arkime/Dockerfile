ARG UBUNTU_VERSION=22.04
FROM ubuntu:$UBUNTU_VERSION
LABEL org.opencontainers.image.authors="mammo0 - https://github.com/mammo0"

# Install dependencies that are needed, but not set in the arkime.deb file
RUN apt-get -qq update && \
    apt-get -yq upgrade && \
    apt-get install -yq curl libmagic-dev wget logrotate

# Set arguments
# TARGETARCH is automatically provided by docker buildx / BuildKit on multi-arch
# builds (amd64, arm64, ...). Falls back to dpkg if someone builds without buildx.
ARG TARGETARCH
ARG ARKIME_VERSION=5.7.0
ARG ARKIME_DEB_PACKAGE="arkime_${ARKIME_VERSION}-1.ubuntu2204_${TARGETARCH:-amd64}.deb"

# Set environment variables
ENV ARKIME_VERSION=$ARKIME_VERSION
ENV OS_HOST="opensearch"
ENV OS_PORT="9200"
ENV OS_USER=""
ENV OS_PASSWORD=""
ENV ARKIME_INTERFACE="eth0"
ENV ARKIME_ADMIN_PASSWORD="admin"
ENV ARKIME_HOSTNAME="localhost"
ENV ARKIMEDIR="/opt/arkime"
ENV CAPTURE="off"
ENV VIEWER="on"

# Install Arkime
RUN mkdir -p /data && \
    cd /data && \
    curl -L -O "https://github.com/arkime/arkime/releases/download/v${ARKIME_VERSION}/${ARKIME_DEB_PACKAGE}" && \
    dpkg -i "${ARKIME_DEB_PACKAGE}" || true && \
    apt-get install -yqf && \
    mv "${ARKIMEDIR}/etc" /data/config && \
    ln -s /data/config "${ARKIMEDIR}/etc" && \
    ln -s /data/logs "${ARKIMEDIR}/logs" && \
    ln -s /data/pcap "${ARKIMEDIR}/raw" && \
    # create the etc/oui.txt
    # It's needed for importing PCAPs. This step is omitted during 'Configure', because ARKIME_INET=no is set in 'startarkime.sh'
    "${ARKIMEDIR}/bin/arkime_update_geo.sh"
# Clean up
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/* && \
    rm "/data/${ARKIME_DEB_PACKAGE}"

# Add scripts
ADD /scripts /data/
RUN chmod 755 /data/*.sh

VOLUME ["/data/pcap", "/data/config", "/data/logs"]
EXPOSE 8005
WORKDIR "$ARKIMEDIR"

ENTRYPOINT ["/data/startarkime.sh"]
