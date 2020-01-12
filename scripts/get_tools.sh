#!/bin/sh

set -e

. "$(dirname $0)/tools.sh"

mkdir -p "$TOOLS"

echo "Installing Python packages..."
pip3 install --prefix "$TOOLS" --ignore-installed \
    meson ninja > "$TOOLS/python.log" 2>&1
echo ""

# Build & install gperf.
GPERF_VERSION="3.1"
GPERF_ARCHIVE="gperf-$GPERF_VERSION.tar.gz"
GPERF_URL="https://ftp.gnu.org/pub/gnu/gperf/$GPERF_ARCHIVE"
GPERF_TOOLS_DIR="$TOOLS/gperf-$GPERF_VERSION"

download "$GPERF_URL" "$GPERF_ARCHIVE"

build_gperf()
(
    local src="$GPERF_TOOLS_DIR/src"
    local build="$GPERF_TOOLS_DIR/build"

    extract "$GPERF_ARCHIVE" "$src"

    echo "Building gperf..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$TOOLS" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$TOOLS/gperf.log" 2>&1
)
build_gperf
