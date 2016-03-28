FROM debian:jessie

MAINTAINER datarhei <info@datarhei.org>

ENV RESTREAMER_EDGE_VERSION=0.1.0-rc.1 \
    FFMPEG_VERSION=2.8.6 \
    YASM_VERSION=1.3.0 \
    LAME_VERSION=3_99_5 \
    NGINX_VERSION=1.9.9 \
    NGINX_RTMP_VERSION=1.1.7.10 \

    SRC="/usr/local" \
    LD_LIBRARY_PATH="${SRC}/lib" \
    PKG_CONFIG_PATH="${SRC}/lib/pkgconfig" \

    BUILDDEPS="autoconf automake gcc g++ libtool make nasm unzip zlib1g-dev libssl-dev xz-utils cmake build-essential libpcre3-dev"

RUN rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y --force-yes curl git libpcre3 tar perl ca-certificates apache2-utils libaio1 ${BUILDDEPS} && \

    # yasm
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    curl -LOks "https://www.tortall.net/projects/yasm/releases/yasm-${YASM_VERSION}.tar.gz" && \
    tar xzvf "yasm-${YASM_VERSION}.tar.gz" && \
    cd "yasm-${YASM_VERSION}" && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    rm -rf "${DIR}" && \

    # x264
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    git clone --depth 1 "git://git.videolan.org/x264" && \
    cd x264 && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" \
        --enable-static \
        --disable-cli && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    rm -rf "${DIR}" && \

    # libmp3lame
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    curl -LOks "https://github.com/rbrito/lame/archive/RELEASE__${LAME_VERSION}.tar.gz" && \
    tar xzvf "RELEASE__${LAME_VERSION}.tar.gz" && \
    cd "lame-RELEASE__${LAME_VERSION}" && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" \
        --enable-nasm \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    rm -rf "${DIR}" && \

    # ffmpeg
    # patch: andrew-shulgin Ignore invalid sprop-parameter-sets missing PPS
    DIR="$(mktemp -d)" && cd "${DIR}" && \
    curl -LOks "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" && \
    tar xzvf "ffmpeg-${FFMPEG_VERSION}.tar.gz" && \
    cd "ffmpeg-${FFMPEG_VERSION}" && \
    curl -Lks "https://github.com/FFmpeg/FFmpeg/commit/1c7e2cf9d33968375ee4025d2279c937e147dae2.patch" | patch -p1 && \
    ./configure \
        --prefix="${SRC}" \
        --bindir="${SRC}/bin" \
        --extra-cflags="-I${SRC}/include" \
        --extra-ldflags="-L${SRC}/lib" \
        --extra-libs=-ldl \
        --enable-nonfree \
        --enable-gpl \
        --enable-version3 \
        --enable-avresample \
        --enable-libmp3lame \
        --enable-libx264 \
        --enable-openssl \
        --enable-postproc \
        --enable-small \
        --disable-debug \
        --disable-doc \
        --disable-ffserver && \
    make -j"$(nproc)" && \
    make install && \
    make distclean && \
    hash -r && \
    cd tools && \
    make qt-faststart && \
    cp qt-faststart "${SRC}/bin" && \
    rm -rf "${DIR}" && \
    echo "${SRC}/lib" > "/etc/ld.so.conf.d/libc.conf" && \
    ffmpeg -buildconf && \

    # nginx-rtmp
    DIR=$(mktemp -d) && cd ${DIR} && \
    curl -LOks "https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.tar.gz" && \
    tar xzvf "release-${NGINX_VERSION}.tar.gz" && \
    curl -LOks "https://github.com/sergey-dryabzhinsky/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz" && \
    tar xzvf "v${NGINX_RTMP_VERSION}.tar.gz" && \
    curl -LOks https://github.com/vozlt/nginx-module-vts/archive/master.zip && \
    unzip master.zip && \
    rm master.zip && \
    curl -LOks https://github.com/nginx/njs/archive/master.zip && \
    unzip master.zip && \
    rm master.zip && \
    cd nginx-release-${NGINX_VERSION} && \
    auto/configure \
        --with-file-aio \
        --with-http_ssl_module \
        --add-module="../nginx-module-vts-master" \
        --add-module="../njs-master/nginx" \
        --add-module="../nginx-rtmp-module-${NGINX_RTMP_VERSION}" && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf ${DIR} && \
        
    apt-get purge -y --auto-remove ${BUILDDEPS} && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/tmp/* && \
    rm -rf /tmp/*

ADD templates /templates
ADD favicon.ico /usr/local/nginx/html/favicon.ico
ADD run.sh /run.sh
RUN mkdir /usr/local/nginx/conf/vhost && \
    mkdir /usr/local/nginx/conf/vhost/www && \
    mkdir /usr/local/nginx/conf/vhost/rtmp && \
    mkdir /usr/local/nginx/html/images && \
    chmod 777 /usr/local/nginx/html/images && \
    chmod +x /run.sh && \
    
    # clappr-player
    DIR=$(mktemp -d) && cd ${DIR} && \
    curl -LOks "https://github.com/clappr/clappr/archive/master.tar.gz" && \
    tar xzvf "master.tar.gz" && \
    rm master.tar.gz && \
    curl -LOks "https://github.com/clappr/clappr-level-selector-plugin/archive/master.tar.gz" && \
    tar xzvf "master.tar.gz" && \
    rm master.tar.gz && \
    mv * /usr/local/nginx/html && \
    rm -rf ${DIR}
    
ENV WORKER_PROCESSES=1 \
    WORKER_CONNECTIONS=1024 \
    
    RTMP_ACCESS_LOG=off \

    RTMP_SERVER_PORT=1935 \
    RTMP_SERVER_TIMEOUT=60s \
    RTMP_SERVER_PING=3m \
    RTMP_SERVER_PING_TIMEOUT=30s \
    RTMP_SERVER_MAX_STREAMS=32 \
    RTMP_SERVER_ACK_WINDOW=5000000 \
    RTMP_SERVER_CHUNK_SIZE=4096 \
    RTMP_SERVER_MAX_MESSAGE=1M \
    RTMP_SERVER_BUFLEN=5s \
    RTMP_SERVER_HLS_FRAGMENT=2s \
    RTMP_SERVER_HLS_PLAYLIST_LENGTH=60 \
    RTMP_SERVER_HLS_SYNC=1ms \
    RTMP_SERVER_HLS_CONTINOUS=off \
    RTMP_SERVER_HLS_NESTED=off \
    RTMP_SERVER_HLS_CLEANUP=on \
    RTMP_SERVER_HLS_FRAGMENT_NAMING=sequential \
    RTMP_SERVER_HLS_FRAGMENT_NAMING_GRANULARITY=0 \
    RTMP_SERVER_HLS_FRAGMENT_SLICING=plain \
    RTMP_SERVER_HLS_TYPE=live \
    RTMP_SERVER_HLS_KEY=off \
    RTMP_SERVER_HLS_FRAGMENTS_PER_KEY=0 \
    RTMP_SERVER_HLS_MAX_CONNECTIONS=1000 \
    RTMP_SERVER_HLS_SNAPSHOT_INTERVAL=60 \
    RTMP_SERVER_HLS_TRANSCODING=false \
    RTMP_SERVER_HLS_TRANSCODING_PROFILES=240p,360p,480p,720p \
    RTMP_SERVER_HLS_PUBLISH_TOKEN=datarhei \

    HTTP_SENDFILE=off \
    HTTP_TCP_NOPUSH=on \
    HTTP_AIO=on \
    HTTP_DIRECTIO=512 \
    HTTP_ACCESS_LOG=off \

    HTTP_SERVER_PORT=80 \
    HTTP_SERVER_HLS_ACCESS_CONTROL_ALLOW_ORIGIN=* \
    HTTP_SERVER_HLS_STATUS_USERNAME=admin \
    HTTP_SERVER_HLS_STATUS_PASSWORD=datarhei

CMD ["/run.sh"]
