#!/bin/sh

set -e

. "$(dirname $0)/mingw.sh"

SRC="$MINGW_TOOLCHAIN/src"
BUILD="$MINGW_TOOLCHAIN/build"
LOG="$MINGW_TOOLCHAIN/log"
mkdir -p "$LOG"

BINUTILS_VERSION="2.33.1"
BINUTILS_ARCHIVE="binutils-$BINUTILS_VERSION.tar.xz"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/$BINUTILS_ARCHIVE"
BINUTILS_DIR="binutils-$BINUTILS_VERSION"
BINUTILS_SRC="$SRC/$BINUTILS_DIR"

GCC_VERSION="9.2.0"
GCC_ARCHIVE="gcc-$GCC_VERSION.tar.xz"
GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/$GCC_ARCHIVE"
GCC_DIR="gcc-$GCC_VERSION"
GCC_SRC="$SRC/$GCC_DIR"

MINGW_VERSION="7.0.0"
MINGW_ARCHIVE="mingw-w64-v$MINGW_VERSION.tar.bz2"
MINGW_URL="https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/$MINGW_ARCHIVE"
MINGW_DIR="mingw-w64-v$MINGW_VERSION"
MINGW_SRC="$SRC/$MINGW_DIR"
MINGW_INSTALL="$MINGW_TOOLCHAIN_INSTALL/$MINGW_TARGET"

echo "Downloading source code..."
download "$BINUTILS_URL" "$BINUTILS_ARCHIVE"
download "$GCC_URL" "$GCC_ARCHIVE"
download "$MINGW_URL" "$MINGW_ARCHIVE"
echo ""

echo "Extracting source code..."
extract "$BINUTILS_ARCHIVE" "$BINUTILS_SRC"
extract "$GCC_ARCHIVE" "$GCC_SRC"
extract "$MINGW_ARCHIVE" "$MINGW_SRC"
echo ""

mkdir -p "$MINGW_TOOLCHAIN_INSTALL"
# Before building, put installation directory into PATH.
# (${parameter:+word} -- if parameter is set and is not null,
#  then substitute the value of word). 
PATH=$MINGW_TOOLCHAIN_INSTALL/bin${PATH:+:$PATH}

# Build and install binutils.
build_binutils()
(
    local build="$BUILD/$BINUTILS_DIR"

    echo "Building binutils..."
    mkdir -p "$build"
    (
        cd "$build"
        "$BINUTILS_SRC/configure" --prefix="$MINGW_TOOLCHAIN_INSTALL" \
            --target="$MINGW_TARGET" --disable-bootstrap \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/binutils.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/binutils.log"
)
build_binutils

# Build and install only the compiler to bootstrap the mingw libraries.
build_gcc_base()
(
    local build="$BUILD/$GCC_DIR-base"

    echo "Building gcc-base..."
    mkdir -p "$build"
    (
        cd "$build"
        "$GCC_SRC/configure" --prefix="$MINGW_TOOLCHAIN_INSTALL" \
            --target="$MINGW_TARGET" --disable-bootstrap \
            --enable-languages=c,c++ --enable-checking=release \
            --disable-shared --enable-static --disable-multilib
        $MAKE -j$PROCS all-gcc
        $MAKE install-gcc
    ) > "$LOG/gcc-base.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/gcc-base.log"
)
build_gcc_base

echo ""

# Install mingw (headers, crt, winpthreads).
install_mingw_headers()
(
    local build="$BUILD/$MINGW_DIR/headers"

    echo "Installing mingw headers..."
    mkdir -p "$build"
    (
        cd "$build"
        "$MINGW_SRC/mingw-w64-headers/configure" --host="$MINGW_TARGET" \
            --prefix="$MINGW_INSTALL"
        $MAKE install
    ) > "$LOG/mingw-headers.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/mingw-headers.log"
)
install_mingw_headers

build_mingw_crt()
(
    local build="$BUILD/$MINGW_DIR/crt"

    echo "Building mingw crt..."
    mkdir -p "$build"
    (
        cd "$build"
        "$MINGW_SRC/mingw-w64-crt/configure" --host="$MINGW_TARGET" \
            --prefix="$MINGW_INSTALL" \
            --disable-lib32 --enable-lib64
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/mingw-crt.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/mingw-crt.log"
)
build_mingw_crt

build_mingw_winpthreads()
(
    local build="$BUILD/$MINGW_DIR/winpthreads"

    echo "Building mingw winpthreads..."
    mkdir -p "$build"
    (
        cd "$build"
        "$MINGW_SRC/mingw-w64-libraries/winpthreads/configure" \
            --host="$MINGW_TARGET" --prefix="$MINGW_INSTALL" \
            --enable-static --disable-shared
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/mingw-winpthreads.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/mingw-winpthreads.log"
)
build_mingw_winpthreads

echo ""

# Build and install full GCC.
build_gcc()
(
    local build="$BUILD/$GCC_DIR"

    echo "Building gcc..."
    mkdir -p "$build"
    (
        cd "$build"
        "$GCC_SRC/configure" --prefix="$MINGW_TOOLCHAIN_INSTALL" \
            --target="$MINGW_TARGET" --disable-bootstrap \
            --enable-languages=c,c++ --enable-threads=posix \
            --enable-checking=release \
            --disable-shared --enable-static --disable-multilib
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/gcc.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/gcc.log"
)
build_gcc

echo ""

echo "DONE"
exit 0
