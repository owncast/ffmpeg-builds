# Owncast FFmpeg builds

The FFmpeg build script provides an easy way to build a **static** build of FFmpeg for **Linux**.

## Background

The Owncast project offers a [quick installer script](https://owncast.online/quickstart/installer/) as an option to install the live video streaming server. A part of this script is determining if [FFmpeg](https://ffmpeg.org/) is already downloaded on the target machine. If not, it will download a static build of FFmpeg for Linux for either amd64 or arm64.

However, as of recent versions of Debian that no longer supports old versions of glib, the static builds that this script has relied on to download are no longer compatible and will segfault. Additionally, any alternative static builds that are available are outdated or not maintained.

To solve this issue, it is necessary to create our own FFmpeg builds that are compatible with the latest Debian releases. These builds are based on the FFmpeg source code and are compiled with the necessary dependencies to ensure compatibility with modern systems.

These builds are available for download and can be used as a drop-in replacement for the existing FFmpeg linux builds used by the Owncast installer script.

## Original work

This repository is a fork of [ffmpeg-build-script](https://github.com/markus-perl/ffmpeg-build-script) by markus-perl.

## Run

1. Install [Earthly](https://earthly.dev/get-earthly) build tools.
2. Install [QEMU](https://www.qemu.org/download/) for [cross-compilation](https://docs.earthly.dev/docs/guides/multi-platform#prerequisites-for-emulation).
3. run `earthly --ci +multi-platform` to build for amd64 and arm64 architectures.
4. Wait.
5. The build archives will be available in the `builds` directory.

## VAAPI Support

There will be two builds created for each architecture: one with VAAPI support enabled, and one without. The goal will be to eventually update the Owncast installer script to download the VAAPI-enabled build if the target machine supports it. If the target machine without VAAPI support were to download a VAAPI-enabled build, ffmpeg would crash, as it would try to dynamically load the VAAPI libraries, which would not be present on the target machine.

## Non-free codecs

While it's possible to create a build that includes non-free codecs, it's not recommended due to potential legal issues. If you find this binary is shipping a non-free codec, or any other please licensing incompatibility please open an issue, or better yet, a PR to improve this build so everyone can benefit from it.

## Possible TODOs

- Add support for more ARM architectures (e.g. armhf, etc).
- Create macOS binaries as well while we're at it, though this is not necessary since the existing macOS FFmpeg binaries are working fine.
- Allow people to manually run the build script with custom options to enable NVIDIA NVENC support. We can't ship this, but people can build it themselves.
- Enable cross-compilation without emulation.
