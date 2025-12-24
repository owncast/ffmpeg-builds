VERSION 0.8

build-base-alpine:
    FROM alpine:3.19
    ARG TARGETARCH  # Built-in Earthly variable
    WORKDIR /app

    # Install build dependencies for static builds with musl
    # Musl is required because static glibc has broken pthread/threading
    RUN --mount=type=cache,target=/var/cache/apk \
        apk add --no-cache \
            build-base \
            curl \
            ca-certificates \
            python3 \
            ninja \
            meson \
            git \
            bash \
            nasm \
            yasm \
            cmake \
            pkgconfig \
            linux-headers \
            coreutils \
            diffutils \
            perl \
            m4 \
            autoconf \
            automake \
            libtool \
            zlib-dev \
            zlib-static \
            libogg-dev \
            openssl-dev \
            openssl-libs-static \
            gettext-dev \
            gperf

build-base:
    FROM ubuntu:24.04
    ARG TARGETARCH  # Built-in Earthly variable
    WORKDIR /app

    # Install build dependencies
    RUN --mount=type=cache,target=/var/cache/apt \
        apt-get update && \
        apt-get -y --no-install-recommends install \
            build-essential \
            curl \
            ca-certificates \
            python3 \
            python-is-python3 \
            ninja-build \
            meson \
            git \
            bash \
            nasm \
            yasm \
            cmake \
            pkg-config \
            autoconf \
            automake \
            libtool \
            perl \
            m4 \
            coreutils \
            diffutils \
            gperf && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

build:
    FROM +build-base-alpine
    ARG TARGETARCH  # Built-in Earthly variable
    ARG FFMPEG_VERSION=8.0

    COPY ./build-ffmpeg ./build-ffmpeg
    ARG SKIPINSTALL=yes
    # Cache both packages (.done files, source) and workspace (installed libs, .pc files)
    # Copy ffmpeg binary out before RUN ends since cache isn't available in subsequent steps
    # ONE TIME: Clear all .done files to sync caches after adding workspace cache
    RUN --mount=type=cache,target=/app/packages,id=ffmpeg-packages-musl-$TARGETARCH \
        --mount=type=cache,target=/app/workspace,id=ffmpeg-workspace-musl-$TARGETARCH \
        rm -f /app/packages/*.done 2>/dev/null || true && \
        ./build-ffmpeg --build --enable-gpl --full-static && \
        cp -r /app/workspace/bin /app/built-bin

    # Test the binary
    RUN /app/built-bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETARCH-static.tar.gz -C /app/built-bin ffmpeg
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETARCH-static.tar.gz
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETARCH-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-$TARGETARCH-static.tar.gz

build-vaapi:
    FROM +build-base
    ARG TARGETARCH  # Built-in Earthly variable
    ARG FFMPEG_VERSION=8.0

    # Install vaapi-specific dependencies
    RUN --mount=type=cache,target=/var/cache/apt \
        apt-get update && \
        apt-get -y --no-install-recommends install \
            libva-dev \
            vainfo && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

    COPY ./build-ffmpeg ./build-ffmpeg
    ARG SKIPINSTALL=yes
    # Cache both packages and workspace, copy binary out for subsequent steps
    # ONE TIME: Clear all .done files to sync caches after adding workspace cache
    RUN --mount=type=cache,target=/app/packages,id=ffmpeg-packages-glibc-vaapi-$TARGETARCH \
        --mount=type=cache,target=/app/workspace,id=ffmpeg-workspace-glibc-vaapi-$TARGETARCH \
        rm -f /app/packages/*.done 2>/dev/null || true && \
        ./build-ffmpeg --build --enable-gpl --latest && \
        cp -r /app/workspace/bin /app/built-bin

    # Test the binary
    RUN /app/built-bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETARCH-vaapi.tar.gz -C /app/built-bin ffmpeg
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETARCH-vaapi.tar.gz
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETARCH-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-$TARGETARCH-vaapi.tar.gz

runtime:
    FROM ubuntu:24.04

    ARG TARGETARCH  # Built-in Earthly variable
    ARG DEBIAN_FRONTEND=noninteractive

    RUN --mount=type=cache,target=/var/cache/apt \
        apt-get update && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Default target
all:
    BUILD +build
    BUILD +build-vaapi
    BUILD +runtime

# Quick debug target for Alpine (static build)
debug-harfbuzz-alpine:
    FROM +build-base-alpine
    ARG TARGETARCH

    WORKDIR /app
    RUN mkdir -p workspace packages

    # Build FreeType2
    RUN curl -L "https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz" -o freetype.tar.xz && \
        tar xf freetype.tar.xz && \
        cd freetype-2.13.3 && \
        ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static && \
        make -j$(nproc) && \
        make install

    # Build expat (fontconfig dependency)
    RUN curl -L "https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz" -o expat.tar.xz && \
        tar xf expat.tar.xz && \
        cd expat-2.6.4 && \
        ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static && \
        make -j$(nproc) && \
        make install

    # Build fontconfig (for font discovery)
    RUN curl -L "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" -o fontconfig.tar.xz && \
        tar xf fontconfig.tar.xz && \
        cd fontconfig-2.15.0 && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static --disable-docs --disable-cache-build --disable-nls && \
        make -j$(nproc) && \
        make install

    # Build harfbuzz
    RUN curl -L "https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz" -o harfbuzz.tar.xz && \
        tar xf harfbuzz.tar.xz && \
        cd harfbuzz-10.1.0 && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" meson setup build \
            --prefix="/app/workspace" \
            --libdir=lib \
            --buildtype=release \
            --default-library=static \
            -Dfreetype=enabled \
            -Dglib=disabled \
            -Dgobject=disabled \
            -Dcairo=disabled \
            -Dicu=disabled \
            -Dtests=disabled \
            -Ddocs=disabled && \
        ninja -C build && \
        ninja -C build install

    # Verify pkg-config and test ffmpeg configure - all in one RUN to see full output
    RUN set -x && \
        echo "=== Checking pkgconfig directory ===" && \
        ls -la /app/workspace/lib/pkgconfig/ && \
        echo "=== fontconfig.pc contents ===" && \
        cat /app/workspace/lib/pkgconfig/fontconfig.pc && \
        echo "=== Testing pkg-config (normal) ===" && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" pkg-config --libs fontconfig && \
        echo "=== Testing pkg-config (static - what ffmpeg uses) ===" && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" pkg-config --static --libs fontconfig && \
        echo "=== Downloading ffmpeg ===" && \
        curl -L "https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz" -o ffmpeg.tar.xz && \
        tar xf ffmpeg.tar.xz && \
        cd ffmpeg-7.1 && \
        echo "=== Running ffmpeg configure ===" && \
        export PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" && \
        (./configure \
            --enable-gpl \
            --enable-libfreetype \
            --enable-libfontconfig \
            --enable-libharfbuzz \
            --disable-ffnvcodec \
            --disable-debug \
            --extra-cflags="-I/app/workspace/include" \
            --extra-ldflags="-L/app/workspace/lib" \
            --pkg-config-flags="--static" \
            --prefix="/app/workspace" || (echo "=== config.log tail ===" && tail -100 ffbuild/config.log && false)) && \
        echo "SUCCESS: ffmpeg configure completed on Alpine!"

# Quick debug target to test harfbuzz + fontconfig build + ffmpeg configure (no compile)
debug-harfbuzz:
    FROM +build-base
    ARG TARGETARCH

    # Install vaapi deps and gperf (for fontconfig) like the real build
    RUN apt-get update && apt-get -y --no-install-recommends install libva-dev vainfo gperf

    WORKDIR /app
    RUN mkdir -p workspace packages

    # Build FreeType2
    RUN curl -L "https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz" -o freetype.tar.xz && \
        tar xf freetype.tar.xz && \
        cd freetype-2.13.3 && \
        ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static && \
        make -j$(nproc) && \
        make install

    # Build expat (fontconfig dependency)
    RUN curl -L "https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz" -o expat.tar.xz && \
        tar xf expat.tar.xz && \
        cd expat-2.6.4 && \
        ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static && \
        make -j$(nproc) && \
        make install

    # Build fontconfig (for font discovery)
    RUN curl -L "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" -o fontconfig.tar.xz && \
        tar xf fontconfig.tar.xz && \
        cd fontconfig-2.15.0 && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" ./configure --prefix="/app/workspace" --libdir="/app/workspace/lib" --disable-shared --enable-static --disable-docs --disable-cache-build --disable-nls && \
        make -j$(nproc) && \
        make install

    # Build harfbuzz (--libdir=lib ensures .pc file goes to lib/pkgconfig, not lib/x86_64-linux-gnu/pkgconfig)
    RUN curl -L "https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz" -o harfbuzz.tar.xz && \
        tar xf harfbuzz.tar.xz && \
        cd harfbuzz-10.1.0 && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" meson setup build \
            --prefix="/app/workspace" \
            --libdir=lib \
            --buildtype=release \
            --default-library=static \
            -Dfreetype=enabled \
            -Dglib=disabled \
            -Dgobject=disabled \
            -Dcairo=disabled \
            -Dicu=disabled \
            -Dtests=disabled \
            -Ddocs=disabled && \
        ninja -C build && \
        ninja -C build install

    # Verify pkg-config can find harfbuzz and fontconfig
    RUN echo "=== Checking pkg-config ===" && \
        ls -la /app/workspace/lib/pkgconfig/ && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" pkg-config --exists harfbuzz fontconfig && \
        echo "SUCCESS: harfbuzz and fontconfig found via pkg-config"

    # Download and configure ffmpeg (no compile) to verify it finds everything
    RUN curl -L "https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz" -o ffmpeg.tar.xz && \
        tar xf ffmpeg.tar.xz && \
        cd ffmpeg-7.1 && \
        PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" ./configure \
            --enable-gpl \
            --enable-libfreetype \
            --enable-libfontconfig \
            --enable-libharfbuzz \
            --disable-ffnvcodec \
            --disable-debug \
            --extra-cflags="-I/app/workspace/include" \
            --extra-ldflags="-L/app/workspace/lib" \
            --pkg-config-flags="--static" \
            --prefix="/app/workspace" && \
        echo "SUCCESS: ffmpeg configure completed with freetype, fontconfig, and harfbuzz!"

multi-platform:
    FROM ubuntu:24.04
    ARG FFMPEG_VERSION=8.0
    
    # Copy artifacts from builds and save them locally
    COPY --platform=linux/amd64 (+build/ffmpeg$FFMPEG_VERSION-amd64-static.tar.gz) ./
    COPY --platform=linux/arm64 (+build/ffmpeg$FFMPEG_VERSION-arm64-static.tar.gz) ./
    COPY --platform=linux/amd64 (+build-vaapi/ffmpeg$FFMPEG_VERSION-amd64-vaapi.tar.gz) ./
    COPY --platform=linux/arm64 (+build-vaapi/ffmpeg$FFMPEG_VERSION-arm64-vaapi.tar.gz) ./
    
    # Save all to local builds directory
    SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-amd64-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-amd64-static.tar.gz
    SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-arm64-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-arm64-static.tar.gz
    SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-amd64-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-amd64-vaapi.tar.gz
    SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-arm64-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-arm64-vaapi.tar.gz

