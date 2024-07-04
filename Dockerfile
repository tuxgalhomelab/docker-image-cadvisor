# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-scripts

COPY scripts/start-cadvisor.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

SHELL ["/bin/bash", "-c"]

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG CADVISOR_VERSION

# hadolint ignore=DL4006,SC2086
RUN --mount=type=bind,target=/scripts,from=with-scripts,source=/scripts \
    set -E -e -o pipefail \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    # Download and install the release. \
    && mkdir -p /tmp/cadvisor \
    && PKG_ARCH="$(dpkg --print-architecture)" \
    && curl \
        --silent \
        --fail \
        --location \
        --remote-name \
        --output-dir /tmp/cadvisor https://github.com/google/cadvisor/releases/download/${CADVISOR_VERSION:?}/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} \
    && mkdir -p /opt/cadvisor-${CADVISOR_VERSION:?} \
    && ln -sf /opt/cadvisor-${CADVISOR_VERSION:?} /opt/cadvisor \
    && cp /tmp/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} /opt/cadvisor/ \
    && chmod +x /opt/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} \
    && ln -sf /opt/cadvisor/cadvisor-${CADVISOR_VERSION:?}-linux-${PKG_ARCH:?} /opt/bin/cadvisor \
    # Copy the start-cadvisor.sh script. \
    && cp /scripts/start-cadvisor.sh /opt/cadvisor/ \
    && ln -sf /opt/cadvisor/start-cadvisor.sh /opt/bin/start-cadvisor \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /opt/cadvisor-${CADVISOR_VERSION:?} /opt/cadvisor /opt/bin/cadvisor /opt/bin/start-cadvisor \
    # Clean up. \
    && rm -rf /tmp/cadvisor \
    && homelab cleanup

# Expose the HTTP server port used by cAdvisor.
EXPOSE 8080

# Use the healthcheck command part of cadvisor as the health checker.
HEALTHCHECK --start-period=1m --interval=30s --timeout=3s CMD curl --silent --fail --location --show-error http://localhost:8080/healthz

ENV USER=${USER_NAME}
ENV PATH="/opt/bin:${PATH}"

USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}
CMD ["start-cadvisor"]
STOPSIGNAL SIGTERM
