VERSION 0.8

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
            git && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

build:
    FROM +build-base
    ARG TARGETARCH  # Built-in Earthly variable
    ARG FFMPEG_VERSION=8.0

    COPY ./build-ffmpeg ./build-ffmpeg
    ARG SKIPINSTALL=yes
    RUN ./build-ffmpeg --build --enable-gpl-and-non-free --full-static 

    # Test the binary
    RUN ./workspace/bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETARCH-static.tar.gz -C /app/workspace/bin ffmpeg
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
    RUN ./build-ffmpeg --build --enable-gpl-and-non-free

    # Test the binary
    RUN ./workspace/bin/ffmpeg -version

    # Save artifacts with explicit paths
    RUN tar -czf /ffmpeg$FFMPEG_VERSION-$TARGETARCH-vaapi.tar.gz -C /app/workspace/bin ffmpeg
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

multi-platform:
    BUILD --platform=linux/amd64 --build-arg SKIPINSTALL=yes +build
    BUILD --platform=linux/arm64 --build-arg SKIPINSTALL=yes +build
    BUILD --platform=linux/amd64 --build-arg SKIPINSTALL=yes +build-vaapi
    BUILD --platform=linux/arm64 --build-arg SKIPINSTALL=yes +build-vaapi
    BUILD --platform=linux/amd64 +runtime
    BUILD --platform=linux/arm64 +runtime

