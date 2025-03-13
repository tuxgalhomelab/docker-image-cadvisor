# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG

ARG GO_IMAGE_NAME
ARG GO_IMAGE_TAG
FROM ${GO_IMAGE_NAME}:${GO_IMAGE_TAG} AS builder

ARG CADVISOR_VERSION

COPY scripts/start-cadvisor.sh /scripts/
COPY patches /patches

# hadolint ignore=DL4006,SC3009
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install build-essential git patch \
    && mkdir -p /root/cadvisor-build \
    # Download cadvisor repo. \
    && homelab download-git-repo \
        https://github.com/google/cadvisor/ \
        ${CADVISOR_VERSION:?} \
        /root/cadvisor-build \
    && pushd /root/cadvisor-build \
    # Apply the patches. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -r -n 1 patch -p2 -i) \
    # Build cAdvisor. \
    && make build \
    && popd \
    # Copy the build artifacts. \
    && mkdir -p /output/{bin,scripts} \
    && cp /root/cadvisor-build/_output/cadvisor /output/bin \
    && cp /scripts/* /output/scripts

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG CADVISOR_VERSION

# hadolint ignore=SC3040
RUN --mount=type=bind,target=/cadvisor-build,from=builder,source=/output \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && mkdir -p /opt/cadvisor-${CADVISOR_VERSION:?} \
    && ln -sf /opt/cadvisor-${CADVISOR_VERSION:?} /opt/cadvisor \
    && cp /cadvisor-build/bin/cadvisor /opt/cadvisor/ \
    && setcap cap_syslog=+ep /opt/cadvisor/cadvisor \
    && ln -sf /opt/cadvisor/cadvisor /opt/bin/cadvisor \
    # Copy the start-cadvisor.sh script. \
    && cp /cadvisor-build/scripts/start-cadvisor.sh /opt/cadvisor/ \
    && ln -sf /opt/cadvisor/start-cadvisor.sh /opt/bin/start-cadvisor \
    # Clean up. \
    && rm -rf /tmp/cadvisor \
    && homelab cleanup

# Expose the HTTP server port used by cAdvisor.
EXPOSE 8080

HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD homelab healthcheck-service http://localhost:8080/healthz

CMD ["start-cadvisor"]
STOPSIGNAL SIGTERM
