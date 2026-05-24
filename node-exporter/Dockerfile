ARG BUILD_FROM
# hadolint ignore=DL3006
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG \
  BUILD_ARCH \
  NODE_EXPORTER_VERSION="1.11.1"

COPY rootfs /

# hadolint ignore=DL3018
RUN \
    apk add --no-cache --update tar su-exec \
    && ARCH="${BUILD_ARCH}" \
    && if [ "${BUILD_ARCH}" = "aarch64" ]; then ARCH="arm64"; fi \
    && curl -J -L -o "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" \
       "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" \
    && curl -J -L -o /tmp/sha256sums.txt \
       "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/sha256sums.txt" \
    && grep "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" /tmp/sha256sums.txt \
       | awk -v f="/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" '{print $1"  "f}' \
       | sha256sum -c - \
    && tar -xzvf "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" --strip-components=1 -C /tmp \
    && mv /tmp/node_exporter /usr/local/bin/ \
    && adduser -s /bin/false -D -H prometheus \
    && chown -R prometheus:prometheus /usr/local/bin/node_exporter \
    && rm -rf /tmp/node_exporter* /tmp/sha256sums.txt LICENSE NOTICE

ENTRYPOINT []

# This add-on runs on the host PID namespace, making it impossible
# to use S6-Overlay. The init system is therefore disabled.
CMD ["/run.sh"]
