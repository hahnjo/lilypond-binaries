#!/bin/sh

set -e

. "$(dirname $0)/common.sh"

mkdir -p "$TOOLS"
mkdir -p "$TOOLS_BIN"

# Download & link Meson.
MESON_VERSION="0.57.2"
MESON_ARCHIVE="meson-$MESON_VERSION.tar.gz"
MESON_URL="https://github.com/mesonbuild/meson/releases/download/$MESON_VERSION/$MESON_ARCHIVE"
MESON_TOOLS_DIR_NAME="meson-$MESON_VERSION"
MESON_TOOLS_DIR="$TOOLS/$MESON_TOOLS_DIR_NAME"

download "$MESON_URL" "$MESON_ARCHIVE"

link_meson()
(
    extract "$MESON_ARCHIVE" "$MESON_TOOLS_DIR"

    echo "Linking meson..."
    ln -s "../$MESON_TOOLS_DIR_NAME/meson.py" "$TOOLS_BIN/meson"
)
link_meson
echo ""

# Build & install Ninja.
NINJA_VERSION="1.10.2"
NINJA_ARCHIVE="ninja-v$NINJA_VERSION.tar.gz"
NINJA_URL="https://github.com/ninja-build/ninja/archive/v$NINJA_VERSION.tar.gz"
NINJA_TOOLS_DIR="$TOOLS/ninja-v$NINJA_VERSION"

download "$NINJA_URL" "$NINJA_ARCHIVE"

build_ninja()
(
    local src="$NINJA_TOOLS_DIR/src"
    local build="$NINJA_TOOLS_DIR/build"

    extract "$NINJA_ARCHIVE" "$src"

    echo "Building ninja..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure.py" --bootstrap
        cp "$build/ninja" "$TOOLS_BIN"
    ) > "$TOOLS/ninja.log" 2>&1 &
    wait $! || print_failed_and_exit "$TOOLS/ninja.log"
)
build_ninja
echo ""

echo "DONE"
exit 0
