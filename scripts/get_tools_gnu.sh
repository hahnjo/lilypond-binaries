#!/bin/sh

set -e

. "$(dirname $0)/common.sh"

mkdir -p "$TOOLS"

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
    ) > "$TOOLS/gperf.log" 2>&1 || print_failed_and_exit "$TOOLS/gperf.log"
)
build_gperf
echo ""

# Build & install texinfo.
TEXINFO_VERSION="6.7"
TEXINFO_ARCHIVE="texinfo-$TEXINFO_VERSION.tar.gz"
TEXINFO_URL="https://ftp.gnu.org/pub/gnu/texinfo/$TEXINFO_ARCHIVE"
TEXINFO_TOOLS_DIR="$TOOLS/texinfo-$TEXINFO_VERSION"

download "$TEXINFO_URL" "$TEXINFO_ARCHIVE"

build_texinfo()
(
    local src="$TEXINFO_TOOLS_DIR/src"
    local build="$TEXINFO_TOOLS_DIR/build"

    extract "$TEXINFO_ARCHIVE" "$src"

    echo "Building texinfo..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$TOOLS" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$TOOLS/texinfo.log" 2>&1 || print_failed_and_exit "$TOOLS/texinfo.log"
)
build_texinfo
echo ""

echo "DONE"
exit 0
