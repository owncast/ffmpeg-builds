#!/bin/bash
set -euo pipefail

# FFmpeg Multi-Platform Test Script
# Tests ffmpeg builds across different OS/architecture combinations
# Uses QEMU for ARM emulation in Docker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FFMPEG_VERSION="8.0"
GITHUB_REPO="owncast/ffmpeg-builds"
RELEASE_BASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download"

# Platforms to test (OS/arch/variant)
# Format: "os:arch:variant:docker_image:platform"
LINUX_PLATFORMS=(
    "linux:amd64:static:alpine:3.19:linux/amd64"
    "linux:amd64:vaapi:ubuntu:24.04:linux/amd64"
    "linux:arm64:static:alpine:3.19:linux/arm64"
    "linux:arm64:vaapi:ubuntu:24.04:linux/arm64"
)

# Darwin platforms (cross-compiled, cannot be tested in Docker)
DARWIN_PLATFORMS=(
    "darwin:amd64"
    "darwin:arm64"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Check if required tools are installed
check_dependencies() {
    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}

# Setup QEMU for multi-architecture support
setup_qemu() {
    log_info "Setting up QEMU for multi-architecture Docker builds..."

    # Check if qemu is already registered
    if docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &> /dev/null; then
        log_info "QEMU binfmt handlers registered successfully"
    else
        log_warn "Could not register QEMU handlers (may already be set up or require privileges)"
    fi
}

# Download ffmpeg artifact for a specific platform
# Args: $1=os, $2=arch, $3=variant (optional)
get_artifact_url() {
    local os="$1"
    local arch="$2"
    local variant="${3:-}"

    local filename="ffmpeg${FFMPEG_VERSION}-${os}-${arch}"
    if [ -n "$variant" ]; then
        filename="${filename}-${variant}"
    fi
    filename="${filename}.tar.gz"

    echo "${RELEASE_BASE_URL}/${filename}"
}

# Test a Linux platform in Docker
# Args: $1=os, $2=arch, $3=variant, $4=docker_image, $5=docker_tag, $6=platform
test_linux_platform() {
    local os="$1"
    local arch="$2"
    local variant="$3"
    local docker_image="$4"
    local docker_tag="$5"
    local platform="$6"

    local artifact_url
    artifact_url=$(get_artifact_url "$os" "$arch" "$variant")
    local test_name="${os}-${arch}-${variant}"
    local container_name="ffmpeg-test-${test_name}"

    log_header "Testing: ${test_name} on ${docker_image}:${docker_tag} (${platform})"

    log_info "Artifact URL: ${artifact_url}"
    log_info "Docker image: ${docker_image}:${docker_tag}"
    log_info "Platform: ${platform}"

    # Create test script to run inside container
    local test_script='
set -e

echo "=== System Information ==="
uname -a
echo ""

echo "=== Downloading ffmpeg ==="
cd /tmp
if command -v curl &> /dev/null; then
    curl -fsSL -o ffmpeg.tar.gz "'"${artifact_url}"'"
elif command -v wget &> /dev/null; then
    wget -q -O ffmpeg.tar.gz "'"${artifact_url}"'"
else
    echo "ERROR: No curl or wget available"
    exit 1
fi
echo "Download complete"

echo ""
echo "=== Extracting ffmpeg ==="
tar -xzf ffmpeg.tar.gz
chmod +x ffmpeg
ls -la ffmpeg
echo ""

echo "=== FFmpeg Version ==="
./ffmpeg -version
echo ""

echo "=== Generating test MP4 ==="
# Generate a 3-second test video with color bars and tone
./ffmpeg -y \
    -f lavfi -i "testsrc=duration=3:size=640x480:rate=30" \
    -f lavfi -i "sine=frequency=440:duration=3" \
    -c:v libx264 -preset ultrafast -crf 23 \
    -c:a aac -b:a 128k \
    -pix_fmt yuv420p \
    test_output.mp4

echo ""
echo "=== Verifying output file ==="
ls -la test_output.mp4
./ffmpeg -i test_output.mp4 -hide_banner 2>&1 | head -20

echo ""
echo "=== TEST PASSED ==="
'

    # Run the test in Docker
    log_info "Starting Docker container..."

    # Remove existing container if it exists
    docker rm -f "${container_name}" 2>/dev/null || true

    local docker_cmd="docker run --rm --name ${container_name} --platform ${platform}"

    # Add curl/wget and required libraries based on image type and variant
    if [[ "$docker_image" == "alpine"* ]]; then
        docker_cmd+=" ${docker_image}:${docker_tag} sh -c 'apk add --no-cache curl > /dev/null 2>&1 && ${test_script}'"
    else
        # For vaapi builds, we need to install libva libraries
        local extra_packages="curl"
        if [[ "$variant" == "vaapi" ]]; then
            extra_packages="curl libva2 libva-drm2"
        fi
        docker_cmd+=" ${docker_image}:${docker_tag} bash -c 'apt-get update > /dev/null 2>&1 && apt-get install -y ${extra_packages} > /dev/null 2>&1 && ${test_script}'"
    fi

    if eval "${docker_cmd}"; then
        log_info "Test PASSED for ${test_name}"
        return 0
    else
        log_error "Test FAILED for ${test_name}"
        return 1
    fi
}

# Test Darwin platforms (download only, cannot execute)
test_darwin_platform() {
    local os="$1"
    local arch="$2"

    local artifact_url
    artifact_url=$(get_artifact_url "$os" "$arch")
    local test_name="${os}-${arch}"

    log_header "Testing (download only): ${test_name}"

    log_info "Artifact URL: ${artifact_url}"
    log_warn "Darwin binaries cannot be executed in Docker - download test only"

    # Download and verify the archive
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf ${temp_dir}" RETURN

    log_info "Downloading artifact..."
    if curl -fsSL -o "${temp_dir}/ffmpeg.tar.gz" "${artifact_url}"; then
        log_info "Download successful"

        log_info "Extracting and verifying..."
        tar -xzf "${temp_dir}/ffmpeg.tar.gz" -C "${temp_dir}"

        if [ -f "${temp_dir}/ffmpeg" ]; then
            log_info "Binary extracted successfully"
            ls -la "${temp_dir}/ffmpeg"
            file "${temp_dir}/ffmpeg" 2>/dev/null || true
            log_info "Test PASSED for ${test_name} (download verification only)"
            return 0
        else
            log_error "Binary not found in archive"
            return 1
        fi
    else
        log_error "Download failed for ${test_name}"
        return 1
    fi
}

# Parse command line arguments
SKIP_QEMU_SETUP=false
TEST_LINUX=true
TEST_DARWIN=true
PARALLEL=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-qemu      Skip QEMU setup (if already configured)"
    echo "  --linux-only     Only test Linux platforms"
    echo "  --darwin-only    Only test Darwin platforms (download verification)"
    echo "  --parallel       Run tests in parallel (experimental)"
    echo "  -h, --help       Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-qemu)
            SKIP_QEMU_SETUP=true
            shift
            ;;
        --linux-only)
            TEST_DARWIN=false
            shift
            ;;
        --darwin-only)
            TEST_LINUX=false
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
main() {
    log_header "FFmpeg Multi-Platform Test Suite"

    log_info "FFmpeg Version: ${FFMPEG_VERSION}"
    log_info "Repository: ${GITHUB_REPO}"
    echo ""

    # Check dependencies
    check_dependencies

    # Setup QEMU for ARM emulation
    if [ "$SKIP_QEMU_SETUP" = false ] && [ "$TEST_LINUX" = true ]; then
        setup_qemu
    fi

    local passed=0
    local failed=0
    local skipped=0

    # Test Linux platforms
    if [ "$TEST_LINUX" = true ]; then
        log_header "Testing Linux Platforms"

        for platform_spec in "${LINUX_PLATFORMS[@]}"; do
            IFS=':' read -r os arch variant docker_image docker_tag docker_platform <<< "$platform_spec"

            if test_linux_platform "$os" "$arch" "$variant" "$docker_image" "$docker_tag" "$docker_platform"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            echo ""
        done
    fi

    # Test Darwin platforms
    if [ "$TEST_DARWIN" = true ]; then
        log_header "Testing Darwin Platforms (Download Only)"

        for platform_spec in "${DARWIN_PLATFORMS[@]}"; do
            IFS=':' read -r os arch <<< "$platform_spec"

            if test_darwin_platform "$os" "$arch"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            echo ""
        done
    fi

    # Summary
    log_header "Test Summary"
    echo -e "  ${GREEN}Passed:${NC}  ${passed}"
    echo -e "  ${RED}Failed:${NC}  ${failed}"
    echo -e "  ${YELLOW}Skipped:${NC} ${skipped}"
    echo ""

    if [ "$failed" -gt 0 ]; then
        log_error "Some tests failed!"
        exit 1
    else
        log_info "All tests passed!"
        exit 0
    fi
}

main
