ARG version=1.18.0
ARG build_dir="/usr/share/tmp"
ARG modules_dir="/usr/lib/nginx/modules"

#
# Nginx builder
#
FROM debian:10.2 AS builder

ARG version
ARG build_dir
ARG modules_dir

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
    echo ${build_dir} && echo ${modules_dir} && \
    mkdir -p ${build_dir} && \
    mkdir -p ${modules_dir}

#
# Download Nginx
#
RUN set -x && \
    cd ${build_dir} && \
    wget https://nginx.org/download/nginx-${version}.tar.gz && \
    tar xzf nginx-${version}.tar.gz && \
    rm nginx-${version}.tar.gz

#
# Download http_proxy_connect
#
RUN set -x && \
    cd ${build_dir} && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module.git

#
# Install Nginx with http_proxy_connect
#
RUN set -x && \
    cd ${build_dir}/nginx-${version} && \
    patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_1018.patch && \
    ./configure --add-dynamic-module=../ngx_http_proxy_connect_module && \
    make && \
    make install

#
# Move compiled module
#
RUN set -x && \
    cd ${build_dir}/nginx-${version} && \
    cp objs/ngx_http_proxy_connect_module.so ${modules_dir}

#
# Server
#
FROM nginx:${version} as server

ARG modles_dir

COPY --from=builder ${modules_dir}/* ${modules_dir}/
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 80 443
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]