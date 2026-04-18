FROM debian:bullseye-slim

# Install dependencies
RUN apt update && apt install -y curl file && rm -rf /var/lib/apt/lists/*

# Download the Velociraptor binary matching the build arch. Velociraptor
# publishes assets named `velociraptor-v<version>-linux-<arch>` where
# <arch> is amd64 or arm64. We detect the build arch at RUN time via
# `dpkg --print-architecture` (the debian:bullseye-slim base always
# matches the build platform) and grep the release JSON for that variant.
# Previously this step hardcoded "linux-amd64", which meant the resulting
# image on arm64 hosts shipped an x86_64 binary and crashed at startup
# with: "cannot execute binary file: Exec format error".
RUN BUILD_ARCH="$(dpkg --print-architecture)" && \
    echo "[velociraptor] build arch = ${BUILD_ARCH}" && \
    curl -s https://api.github.com/repos/Velocidex/velociraptor/releases/latest \
    | grep "browser_download_url" \
    | grep "linux-${BUILD_ARCH}\"" \
    | cut -d '"' -f 4 \
    | xargs curl -L -o /usr/local/bin/velociraptor \
    && chmod +x /usr/local/bin/velociraptor \
    && file /usr/local/bin/velociraptor

# Copy config and entrypoint
COPY server.config.yaml /velociraptor/server.config.yaml
COPY entrypoint.sh /entrypoint.sh

# Ensure entrypoint is executable
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
