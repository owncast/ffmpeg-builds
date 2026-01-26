#!/bin/bash
set -euo pipefail

# FFmpeg multi-platform static build and release script
# This script replicates the GitHub Actions workflow for local execution

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
check_dependencies() {
    local missing=()

    if ! command -v earthly &> /dev/null; then
        missing+=("earthly")
    fi

    if ! command -v gh &> /dev/null; then
        missing+=("gh (GitHub CLI)")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi

    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        exit 1
    fi
}

# Parse command line arguments
SKIP_BUILD=false
SKIP_RELEASE=false
DRY_RUN=false
TAG_NAME=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-build     Skip the Earthly build step (use existing builds)"
    echo "  --skip-release   Skip creating the GitHub release"
    echo "  --dry-run        Show what would be done without executing"
    echo "  --tag NAME       Use a specific tag name (default: timestamp)"
    echo "  -h, --help       Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-release)
            SKIP_RELEASE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --tag)
            TAG_NAME="$2"
            shift 2
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

# Main script
main() {
    log_info "Starting FFmpeg multi-platform build and release"

    # Check dependencies
    check_dependencies

    # Generate timestamp for tag if not provided
    if [ -z "$TAG_NAME" ]; then
        TAG_NAME=$(date +'%Y%m%d%H%M%S')
    fi
    log_info "Using tag: $TAG_NAME"

    # Fetch latest tags
    log_info "Fetching git tags..."
    if [ "$DRY_RUN" = false ]; then
        git fetch --tags
    else
        echo "  [DRY-RUN] Would run: git fetch --tags"
    fi

    # Create builds directory
    rm -rf ./builds
    mkdir -p ./builds

    # Build with Earthly
    if [ "$SKIP_BUILD" = false ]; then
        log_info "Building with Earthly (this may take a while)..."
        if [ "$DRY_RUN" = false ]; then
            earthly --output +multi-platform
        else
            echo "  [DRY-RUN] Would run: earthly --output +multi-platform"
        fi
    else
        log_warn "Skipping build step (--skip-build specified)"
    fi

    # Check if build artifacts exist
    if [ "$SKIP_RELEASE" = false ]; then
        if ! ls ./builds/*.tar.gz 1> /dev/null 2>&1; then
            log_error "No build artifacts found in ./builds/"
            log_error "Run the build first or check if it completed successfully."
            exit 1
        fi

        log_info "Found build artifacts:"
        ls -la ./builds/*.tar.gz
    fi

    # Create GitHub release
    if [ "$SKIP_RELEASE" = false ]; then
        log_info "Creating GitHub release..."

        if [ "$DRY_RUN" = false ]; then
            # Create the release with all tar.gz files
            gh release create "$TAG_NAME" \
                --title "$TAG_NAME" \
                --notes "Updated static FFmpeg builds" \
                --generate-notes \
                ./builds/*.tar.gz

            log_info "Release created successfully!"
            log_info "View release at: $(gh release view "$TAG_NAME" --json url -q .url)"
        else
            echo "  [DRY-RUN] Would run: gh release create $TAG_NAME --title $TAG_NAME --notes 'Updated static FFmpeg builds' --generate-notes ./builds/*.tar.gz"
        fi
    else
        log_warn "Skipping release step (--skip-release specified)"
    fi

    log_info "Done!"
}

main
