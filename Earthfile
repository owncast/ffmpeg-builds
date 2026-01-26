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
    ARG TARGETOS    # Built-in Earthly variable
    ARG FFMPEG_VERSION=8.0

    COPY ./build-ffmpeg ./build-ffmpeg
    ARG SKIPINSTALL=yes
    # Cache both packages (.done files, source) and workspace (installed libs, .pc files)
    # Copy ffmpeg binary out before RUN ends since cache isn't available in subsequent steps
    RUN --mount=type=cache,target=/app/packages,id=ffmpeg-packages-musl-$TARGETARCH \
        --mount=type=cache,target=/app/workspace,id=ffmpeg-workspace-musl-$TARGETARCH \
        ./build-ffmpeg --build --enable-gpl --full-static && \
        cp -r /app/workspace/bin /app/built-bin

    # Test the binary
    RUN /app/built-bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-static.tar.gz -C /app/built-bin ffmpeg
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-static.tar.gz
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-static.tar.gz

build-vaapi:
    FROM +build-base
    ARG TARGETARCH  # Built-in Earthly variable
    ARG TARGETOS    # Built-in Earthly variable
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
    RUN --mount=type=cache,target=/app/packages,id=ffmpeg-packages-glibc-vaapi-$TARGETARCH \
        --mount=type=cache,target=/app/workspace,id=ffmpeg-workspace-glibc-vaapi-$TARGETARCH \
        ./build-ffmpeg --build --enable-gpl --latest && \
        cp -r /app/workspace/bin /app/built-bin

    # Test the binary
    RUN /app/built-bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-vaapi.tar.gz -C /app/built-bin ffmpeg
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-vaapi.tar.gz
    SAVE ARTIFACT /ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-$TARGETOS-$TARGETARCH-vaapi.tar.gz

runtime:
    FROM ubuntu:24.04

    ARG TARGETARCH  # Built-in Earthly variable
    ARG DEBIAN_FRONTEND=noninteractive

    RUN --mount=type=cache,target=/var/cache/apt \
        apt-get update && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Default target (Linux only - darwin requires macOS SDK)
all:
    BUILD +build
    BUILD +build-vaapi
    BUILD +runtime

# Build all platforms including darwin (requires macos-sdk/MacOSX14.0.sdk.tar.xz)
all-platforms:
    BUILD +build
    BUILD +build-vaapi
    BUILD +build-darwin --DARWIN_TARGETARCH=amd64
    BUILD +build-darwin --DARWIN_TARGETARCH=arm64
    BUILD +runtime

# Build darwin targets only (requires macos-sdk/MacOSX14.0.sdk.tar.xz)
darwin:
    BUILD +build-darwin --DARWIN_TARGETARCH=amd64
    BUILD +build-darwin --DARWIN_TARGETARCH=arm64

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

# Darwin build using ghcr.io/gabek/go-crosscompile (has osxcross pre-configured)
build-darwin:
    FROM ghcr.io/gabek/go-crosscompile:latest
    ARG DARWIN_TARGETARCH  # amd64 or arm64
    ARG FFMPEG_VERSION=8.0

    # Install additional build dependencies for FFmpeg (Alpine-based image)
    RUN --mount=type=cache,target=/var/cache/apk \
        apk add --no-cache \
            nasm \
            yasm \
            meson \
            ninja \
            gperf \
            curl \
            xz \
            perl \
            file \
            cmake \
            make \
            pkgconfig

    # Map architecture names for osxcross (darwin23.5 SDK)
    IF [ "$DARWIN_TARGETARCH" = "amd64" ]
        ENV OSXCROSS_HOST="x86_64-apple-darwin23.5"
        ENV DARWIN_ARCH="x86_64"
    ELSE
        ENV OSXCROSS_HOST="aarch64-apple-darwin23.5"
        ENV DARWIN_ARCH="arm64"
    END

    WORKDIR /app
    RUN mkdir -p workspace packages

    # Set cross-compilation environment (osxcross is at /osxcross/target/bin)
    ENV PATH="/osxcross/target/bin:$PATH"
    ENV CC="${OSXCROSS_HOST}-clang"
    ENV CXX="${OSXCROSS_HOST}-clang++"
    ENV AR="${OSXCROSS_HOST}-ar"
    ENV RANLIB="${OSXCROSS_HOST}-ranlib"
    ENV STRIP="${OSXCROSS_HOST}-strip"
    ENV PKG_CONFIG="${OSXCROSS_HOST}-pkg-config"
    ENV PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig"
    ENV CFLAGS="-I/app/workspace/include -arch ${DARWIN_ARCH}"
    ENV LDFLAGS="-L/app/workspace/lib -arch ${DARWIN_ARCH}"
    ENV MACOSX_DEPLOYMENT_TARGET="11.0"
    ENV OSXCROSS_PKG_CONFIG_USE_NATIVE_VARIABLES=1

    # Build zlib using cmake (more reliable for cross-compilation)
    RUN curl -L "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz" -o zlib.tar.gz && \
        tar xf zlib.tar.gz && \
        cd zlib-1.3.1 && \
        mkdir build && cd build && \
        cmake .. \
            -DCMAKE_INSTALL_PREFIX="/app/workspace" \
            -DCMAKE_SYSTEM_NAME=Darwin \
            -DCMAKE_SYSTEM_PROCESSOR=${DARWIN_ARCH} \
            -DCMAKE_C_COMPILER=/osxcross/target/bin/${OSXCROSS_HOST}-clang \
            -DCMAKE_AR=/osxcross/target/bin/${OSXCROSS_HOST}-ar \
            -DCMAKE_RANLIB=/osxcross/target/bin/${OSXCROSS_HOST}-ranlib \
            -DCMAKE_OSX_ARCHITECTURES=${DARWIN_ARCH} \
            -DBUILD_SHARED_LIBS=OFF && \
        make -j$(nproc) && \
        make install

    # Build x264
    RUN curl -L "https://code.videolan.org/videolan/x264/-/archive/be4f0200/x264-be4f0200.tar.gz" -o x264.tar.gz && \
        tar xf x264.tar.gz && \
        cd x264-be4f0200* && \
        ./configure --prefix="/app/workspace" --host=${OSXCROSS_HOST} \
            --cross-prefix=${OSXCROSS_HOST}- \
            --enable-static --enable-pic \
            --extra-cflags="${CFLAGS}" --extra-ldflags="${LDFLAGS}" && \
        make -j$(nproc) && \
        make install

    # Build x265
    RUN curl -L "https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.0.tar.gz" -o x265.tar.gz && \
        tar xf x265.tar.gz && \
        cd x265_4.0/build/linux && \
        cmake ../../source \
            -DCMAKE_INSTALL_PREFIX="/app/workspace" \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_SYSTEM_NAME=Darwin \
            -DCMAKE_SYSTEM_PROCESSOR=${DARWIN_ARCH} \
            -DCMAKE_C_COMPILER=/osxcross/target/bin/${OSXCROSS_HOST}-clang \
            -DCMAKE_CXX_COMPILER=/osxcross/target/bin/${OSXCROSS_HOST}-clang++ \
            -DCMAKE_AR=/osxcross/target/bin/${OSXCROSS_HOST}-ar \
            -DCMAKE_RANLIB=/osxcross/target/bin/${OSXCROSS_HOST}-ranlib \
            -DCMAKE_OSX_ARCHITECTURES=${DARWIN_ARCH} \
            -DENABLE_SHARED=OFF \
            -DENABLE_CLI=OFF && \
        make -j$(nproc) && \
        make install && \
        sed -i 's/-lc++ -lrt -ldl/-lc++/g' /app/workspace/lib/pkgconfig/x265.pc

    # Build FreeType2
    RUN curl -L "https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz" -o freetype.tar.xz && \
        tar xf freetype.tar.xz && \
        cd freetype-2.13.3 && \
        ./configure --prefix="/app/workspace" --host=${OSXCROSS_HOST} \
            --disable-shared --enable-static && \
        make -j$(nproc) && \
        make install

    # Build FFmpeg
    RUN curl -L "https://github.com/FFmpeg/FFmpeg/archive/refs/heads/release/${FFMPEG_VERSION}.tar.gz" -o ffmpeg.tar.gz && \
        tar xf ffmpeg.tar.gz && \
        cd FFmpeg-release-${FFMPEG_VERSION} && \
        export PKG_CONFIG_PATH="/app/workspace/lib/pkgconfig" && \
        ./configure \
            --prefix="/app/workspace" \
            --arch=${DARWIN_ARCH} \
            --target-os=darwin \
            --cross-prefix=${OSXCROSS_HOST}- \
            --cc="/osxcross/target/bin/${OSXCROSS_HOST}-clang" \
            --cxx="/osxcross/target/bin/${OSXCROSS_HOST}-clang++" \
            --ar="/osxcross/target/bin/${OSXCROSS_HOST}-ar" \
            --ranlib="/osxcross/target/bin/${OSXCROSS_HOST}-ranlib" \
            --strip="/osxcross/target/bin/${OSXCROSS_HOST}-strip" \
            --enable-cross-compile \
            --enable-gpl \
            --enable-version3 \
            --enable-static \
            --disable-shared \
            --disable-debug \
            --enable-libx264 \
            --enable-libx265 \
            --enable-libfreetype \
            --disable-videotoolbox \
            --extra-cflags="-I/app/workspace/include" \
            --extra-ldflags="-L/app/workspace/lib" \
            --pkg-config="pkg-config" \
            --pkg-config-flags="--static" && \
        make -j$(nproc) && \
        make install

    # Test that the binary was built (can't run it on Linux)
    RUN file /app/workspace/bin/ffmpeg

    # Package the artifact
    RUN tar -czf /ffmpeg${FFMPEG_VERSION}-darwin-${DARWIN_TARGETARCH}.tar.gz -C /app/workspace/bin ffmpeg
    SAVE ARTIFACT /ffmpeg${FFMPEG_VERSION}-darwin-${DARWIN_TARGETARCH}.tar.gz
    SAVE ARTIFACT /ffmpeg${FFMPEG_VERSION}-darwin-${DARWIN_TARGETARCH}.tar.gz AS LOCAL ./builds/ffmpeg${FFMPEG_VERSION}-darwin-${DARWIN_TARGETARCH}.tar.gz

# Multi-platform build for Linux only
multi-platform-linux:
    FROM ubuntu:24.04
    ARG FFMPEG_VERSION=8.0

    # Copy artifacts from Linux builds and save them locally
    FOR arch IN amd64 arm64
        COPY --platform=linux/$arch (+build/ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz) ./
        COPY --platform=linux/$arch (+build-vaapi/ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz) ./
        SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz
        SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz
    END

# Multi-platform build including darwin (requires macos-sdk/MacOSX14.0.sdk.tar.xz)
multi-platform:
    FROM ubuntu:24.04
    ARG FFMPEG_VERSION=8.0

    # Copy artifacts from Linux builds
    FOR arch IN amd64 arm64
        COPY --platform=linux/$arch (+build/ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz) ./
        COPY --platform=linux/$arch (+build-vaapi/ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz) ./
        SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-linux-$arch-static.tar.gz
        SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-linux-$arch-vaapi.tar.gz
    END

    # Copy artifacts from Darwin builds (cross-compiled)
    FOR arch IN amd64 arm64
        COPY (+build-darwin/ffmpeg$FFMPEG_VERSION-darwin-$arch.tar.gz --DARWIN_TARGETARCH=$arch) ./
        SAVE ARTIFACT ./ffmpeg$FFMPEG_VERSION-darwin-$arch.tar.gz AS LOCAL ./builds/ffmpeg$FFMPEG_VERSION-darwin-$arch.tar.gz
    END

