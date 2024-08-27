# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

COPY scripts/start-cadvisor.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG CADVISOR_VERSION

# hadolint ignore=DL4006,SC2086
RUN --mount=type=bind,target=/scripts,from=with-scripts,source=/scripts \
    set -E -e -o pipefail \
    # Download and install the release. \
    && mkdir -p /tmp/cadvisor \
    && PKG_ARCH="$(dpkg --print-architecture)" \
    && curl \
        --silent \
        --fail \
        --location \
        --show-error \
        --remote-name \
        --output-dir /tmp/cadvisor https://github.com/google/cadvisor/releases/download/${CADVISOR_VERSION:?}/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} \
    && mkdir -p /opt/cadvisor-${CADVISOR_VERSION:?} \
    && ln -sf /opt/cadvisor-${CADVISOR_VERSION:?} /opt/cadvisor \
    && cp /tmp/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} /opt/cadvisor/ \
    && chmod +x /opt/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} \
    && setcap cap_syslog=+ep /opt/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} \
    && ln -sf /opt/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} /opt/bin/cadvisor \
    # Copy the start-cadvisor.sh script. \
    && cp /scripts/start-cadvisor.sh /opt/cadvisor/ \
    && ln -sf /opt/cadvisor/start-cadvisor.sh /opt/bin/start-cadvisor \
    # Clean up. \
    && rm -rf /tmp/cadvisor \
    && homelab cleanup

# Expose the HTTP server port used by cAdvisor.
EXPOSE 8080

HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD curl \
        --silent \
        --fail \
        --location \
        --show-error \
        http://localhost:8080/healthz

CMD ["start-cadvisor"]
STOPSIGNAL SIGTERM
