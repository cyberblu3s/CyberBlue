## variables
REPOSITORY="packages-dev.wazuh.com/pre-release"
WAZUH_TAG=$(curl --silent https://api.github.com/repos/wazuh/wazuh/git/refs/tags | grep '["]ref["]:' | sed -E 's/.*\"([^\"]+)\".*/\1/'  | cut -c 11- | grep ^v${WAZUH_VERSION}$)

## check tag to use the correct repository
if [[ -n "${WAZUH_TAG}" ]]; then
  REPOSITORY="packages.wazuh.com/4.x"
fi

## Detect arch at runtime (rpm on amazonlinux returns x86_64 / aarch64) so
## we download the filebeat RPM matching the build platform. This used to
## hardcode "x86_64.rpm" which broke arm64 image builds with an arch
## mismatch error when yum tried to install an x86_64 RPM on aarch64.
FILEBEAT_ARCH="$(rpm --eval '%{_arch}')"
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-${FILEBEAT_ARCH}.rpm &&\
yum install -y ${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-${FILEBEAT_ARCH}.rpm && rm -f ${FILEBEAT_CHANNEL}-${FILEBEAT_VERSION}-${FILEBEAT_ARCH}.rpm && \
curl -s https://${REPOSITORY}/filebeat/${WAZUH_FILEBEAT_MODULE} | tar -xvz -C /usr/share/filebeat/module