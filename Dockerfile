FROM alpine:3.19

LABEL maintainer="8technologia"
LABEL description="FRPC Client with auto-config and health check"

ARG FRP_VERSION=0.66.0
ARG TARGETARCH

RUN apk add --no-cache curl bash jq python3

RUN case "${TARGETARCH}" in \
    "amd64") ARCH="amd64" ;; \
    "arm64") ARCH="arm64" ;; \
    "arm") ARCH="arm" ;; \
    *) ARCH="amd64" ;; \
    esac && \
    curl -sL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz" -o /tmp/frp.tar.gz && \
    tar -xzf /tmp/frp.tar.gz -C /tmp && \
    mv /tmp/frp_${FRP_VERSION}_linux_${ARCH}/frpc /usr/local/bin/ && \
    chmod +x /usr/local/bin/frpc && \
    rm -rf /tmp/*

COPY entrypoint.sh /entrypoint.sh
COPY config_proxy.py /config_proxy.py
RUN chmod +x /entrypoint.sh

WORKDIR /etc/frpc

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -sf http://127.0.0.1:7402/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
