ARG VERSION=1.18.0
ARG BUILD_DIR="/usr/share/tmp"
ARG MODULES_DIR="/usr/lib/nginx/modules"

#
# Nginx builder
#
FROM debian:10.2 AS builder

ARG VERSION
ARG BUILD_DIR
ARG MODULES_DIR

SHELL ["/bin/bash", "-c"]
ENV build_deps "ca-certificates wget git build-essential libpcre3-dev zlib1g-dev libtool libssl-dev unzip"

#
# Set up system
#
RUN set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends $build_deps

#
# Create directories
#
RUN set -x && \
    echo ${BUILD_DIR} && echo ${MODULES_DIR} && \
    mkdir -p ${BUILD_DIR} && \
    mkdir -p ${MODULES_DIR}

#
# Download Nginx
#
RUN set -x && \
    cd ${BUILD_DIR} && \
    wget https://nginx.org/download/nginx-${VERSION}.tar.gz && \
    tar xzf nginx-${VERSION}.tar.gz && \
    rm nginx-${VERSION}.tar.gz

#
# Download http_proxy_connect
#
RUN set -x && \
    cd ${BUILD_DIR} && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module.git

#
# Install Nginx with http_proxy_connect
#
RUN set -x && \
    cd ${BUILD_DIR}/nginx-${VERSION} && \
    patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_1018.patch && \
    ./configure --add-dynamic-module=../ngx_http_proxy_connect_module && \
    make && \
    make install

#
# Move compiled module
#
RUN set -x && \
    cd ${BUILD_DIR}/nginx-${VERSION} && \
    cp objs/ngx_http_proxy_connect_module.so ${MODULES_DIR} && \
    chmod 644 ${MODULES_DIR}/ngx_http_proxy_connect_module.so

#
# Cleanup
#
RUN set -x && \
    apt-get remove --purge --auto-remove -y

#
# Server
#
# This may not be the solution - The nginx binary compiled above needs to be the one run below
FROM nginx:${VERSION} as server

ARG MODULES_DIR

COPY --from=builder ${MODULES_DIR}/* ${MODULES_DIR}/

COPY docker-entrypoint.sh /
RUN set -x && chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 80 443
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]