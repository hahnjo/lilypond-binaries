#!/bin/sh

set -e

# Build dependencies for LilyPond needed at runtime:
#  * fontconfig
#    * expat
#    * freetype2
#    * util-linux (for libuuid on Linux)
#  * ghostscript
#    * fontconfig
#    * freetype2
#  * glib2
#    * libffi
#    * zlib
#  * guile (version 1.8)
#    * libtool
#    * gmp
#  * pango
#    * cairo
#      * fontconfig
#      * freetype2
#      * pixman
#    * glib2
#    * harfbuzz
#  * python (version 2.7)

. "$(dirname $0)/tools.sh"
. "$(dirname $0)/native_deps.sh"

LOG="$DEPENDENCIES/log"
mkdir -p "$LOG"

echo "Downloading source code..."
download "$EXPAT_URL" "$EXPAT_ARCHIVE"
download "$FREETYPE_URL" "$FREETYPE_ARCHIVE"
download "$UTIL_LINUX_URL" "$UTIL_LINUX_ARCHIVE"
download "$FONTCONFIG_URL" "$FONTCONFIG_ARCHIVE"

download "$GHOSTSCRIPT_URL" "$GHOSTSCRIPT_ARCHIVE"

download "$LIBFFI_URL" "$LIBFFI_ARCHIVE"
download "$ZLIB_URL" "$ZLIB_ARCHIVE"
download "$GLIB2_URL" "$GLIB2_ARCHIVE"

download "$GMP_URL" "$GMP_ARCHIVE"
download "$LIBTOOL_URL" "$LIBTOOL_ARCHIVE"
download "$GUILE_URL" "$GUILE_ARCHIVE"

download "$PIXMAN_URL" "$PIXMAN_ARCHIVE"
download "$CAIRO_URL" "$CAIRO_ARCHIVE"
download "$HARFBUZZ_URL" "$HARFBUZZ_ARCHIVE"
download "$PANGO_URL" "$PANGO_ARCHIVE"

download "$PYTHON_URL" "$PYTHON_ARCHIVE"

# Before building set PKG_CONFIG_LIBDIR="" to avoid pkg-config finding
# dependencies in system directories. This doesn't work in all cases though,
# because for example glib2 tries to just link with a known library name
# if the package cannot be found by pkg-config.
export PKG_CONFIG_LIBDIR=""

# Build expat (dependency of fontconfig)
build_expat()
(
    local src="$SRC/$EXPAT_DIR"
    local build="$BUILD/$EXPAT_DIR"

    extract "$EXPAT_ARCHIVE" "$src"

    echo "Building expat..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$EXPAT_INSTALL" --disable-shared --enable-static \
            --without-xmlwf --without-examples --without-tests
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/expat.log" 2>&1 || print_failed_and_exit "$LOG/expat.log"
)

# Build freetype2 (dependency of fontconfig)
build_freetype2()
(
    local src="$SRC/$FREETYPE_DIR"
    local build="$BUILD/$FREETYPE_DIR"

    extract "$FREETYPE_ARCHIVE" "$src"

    echo "Building freetype2..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$FREETYPE_INSTALL" --disable-shared --enable-static \
            --with-zlib=no --with-bzip2=no --with-png=no --with-harfbuzz=no
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/freetype2.log" 2>&1 || print_failed_and_exit "$LOG/freetype2.log"
)

# Build util-linux
build_util_linux()
(
    local src="$SRC/$UTIL_LINUX_DIR"
    local build="$BUILD/$UTIL_LINUX_DIR"

    extract "$UTIL_LINUX_ARCHIVE" "$src"

    echo "Building util-linux..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$UTIL_LINUX_INSTALL" --disable-shared --enable-static \
            --disable-all-programs --enable-libuuid
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/util-linux.log" 2>&1 || print_failed_and_exit "$LOG/util-linux.log"
)

# Build fontconfig
build_fontconfig()
(
    local src="$SRC/$FONTCONFIG_DIR"
    local build="$BUILD/$FONTCONFIG_DIR"

    extract "$FONTCONFIG_ARCHIVE" "$src"
    # Fix uuid.h inclusion
    sed_i "s|uuid/uuid\\.h|uuid.h|" "$src/configure" \
        "$src/src/fchash.c" "$src/src/fccache.c"
    # Don't build tests
    sed_i "s|po-conf test|po-conf|" "$src/Makefile.in"

    echo "Building fontconfig..."
    mkdir -p "$build"
    (
        cd "$build"
        pkg_config_libdir="$EXPAT_INSTALL/lib/pkgconfig:$FREETYPE_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"
        PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
        "$src/configure" --prefix="$FONTCONFIG_INSTALL" --disable-shared --enable-static \
            --disable-docs
        $MAKE -j$PROCS
        $MAKE install
        # Patch pkgconfig file for static dependencies
        sed_i -e "s|Requires:.*|& uuid expat|" -e "/Requires.private/d" "$FONTCONFIG_INSTALL/lib/pkgconfig/fontconfig.pc"
    ) > "$LOG/fontconfig.log" 2>&1 || print_failed_and_exit "$LOG/fontconfig.log"
)

# Build ghostscript
build_ghostscript()
(
    local src="$SRC/$GHOSTSCRIPT_DIR"
    local build="$BUILD/$GHOSTSCRIPT_DIR"

    extract "$GHOSTSCRIPT_ARCHIVE" "$src"

    echo "Building ghostscript..."
    mkdir -p "$build"
    (
        cd "$build"
        PKG_CONFIG_LIBDIR="$FONTCONFIG_INSTALL/lib/pkgconfig:$FREETYPE_INSTALL/lib/pkgconfig" \
        "$src/configure" --prefix="$GHOSTSCRIPT_INSTALL" --disable-dynamic --with-drivers=PS \
            --without-libidn --without-libpaper --without-libtiff --without-pdftoraster \
            --without-ijs --without-luratech --without-jbig2dec --without-cal \
            --disable-cups --disable-openjpeg --disable-gtk
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/ghostscript.log" 2>&1 || print_failed_and_exit "$LOG/ghostscript.log"
)

# Build libffi (dependency of glib2)
build_libffi()
(
    local src="$SRC/$LIBFFI_DIR"
    local build="$BUILD/$LIBFFI_DIR"

    extract "$LIBFFI_ARCHIVE" "$src"

    echo "Building libffi..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$LIBFFI_INSTALL" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libffi.log" 2>&1 || print_failed_and_exit "$LOG/libffi.log"
)

# Build zlib (dependency of glib2)
build_zlib()
(
    local src="$SRC/$ZLIB_DIR"
    local build="$BUILD/$ZLIB_DIR"

    extract "$ZLIB_ARCHIVE" "$src"

    echo "Building zlib..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$ZLIB_INSTALL" --static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/zlib.log" 2>&1 || print_failed_and_exit "$LOG/zlib.log"
)

# Build glib2
build_glib2()
(
    local src="$SRC/$GLIB2_DIR"
    local build="$BUILD/$GLIB2_DIR"

    extract "$GLIB2_ARCHIVE" "$src"
    # Don't build tests
    sed_i "s|build_tests =.*|build_tests = false|" "$src/meson.build"

    echo "Building glib2..."
    mkdir -p "$build"
    (
        PKG_CONFIG_LIBDIR="$LIBFFI_INSTALL/lib/pkgconfig:$ZLIB_INSTALL/lib/pkgconfig" \
        meson setup --prefix "$GLIB2_INSTALL" --libdir=lib --buildtype plain \
            --default-library static --auto-features=disabled \
            -D internal_pcre=true -D libmount=false -D xattr=false \
            "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"
    ) > "$LOG/glib2.log" 2>&1 || print_failed_and_exit "$LOG/glib2.log"
)

# Build gmp (dependency of guile)
build_gmp()
(
    local src="$SRC/$GMP_DIR"
    local build="$BUILD/$GMP_DIR"

    extract "$GMP_ARCHIVE" "$src"

    echo "Building gmp..."
    mkdir -p "$build"
    (
        cd "$build"
        # gmp tries to target the specific host CPU unless --host is given...
        "$src/configure" --prefix="$GMP_INSTALL" --host="$(cc -dumpmachine)" \
            --disable-shared --enable-static --with-pic
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/gmp.log" 2>&1 || print_failed_and_exit "$LOG/gmp.log"
)

# Build libtool (dependency of guile)
build_libtool()
(
    local src="$SRC/$LIBTOOL_DIR"
    local build="$BUILD/$LIBTOOL_DIR"

    extract "$LIBTOOL_ARCHIVE" "$src"

    echo "Building libtool..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$LIBTOOL_INSTALL" --disable-shared --enable-static --with-pic
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libtool.log" 2>&1 || print_failed_and_exit "$LOG/libtool.log"
)

# Build guile
build_guile()
(
    local src="$SRC/$GUILE_DIR"
    local build="$BUILD/$GUILE_DIR"

    extract "$GUILE_ARCHIVE" "$src"
    # Export dynamic symbols from guile executable so that srfi modules work.
    sed_i "s|guile_LDFLAGS = .*$|& -Wl,--export-dynamic|" "$src/libguile/Makefile.in"

    echo "Building guile..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$GUILE_INSTALL" --disable-shared --enable-static --with-pic \
            --disable-error-on-warning \
            CPPFLAGS="-I$GMP_INSTALL/include -I$LIBTOOL_INSTALL/include" \
            LDFLAGS="-L$GMP_INSTALL/lib -L$LIBTOOL_INSTALL/lib" LIBS="-ldl"
        $MAKE -j$PROCS
        $MAKE install
        # Build shared libraries for srfi modules.
        cd "$GUILE_INSTALL/lib"
        for srfi in 1-v-3 4-v-3 13-14-v-3 60-v-2; do
            lib="libguile-srfi-srfi-$srfi"
            cc -shared -o "$lib.so" -Wl,--whole-archive "$lib.a" -Wl,--no-whole-archive
        done
    ) > "$LOG/guile.log" 2>&1 || print_failed_and_exit "$LOG/guile.log"
)

# Build pixman (dependency of cairo)
build_pixman()
(
    local src="$SRC/$PIXMAN_DIR"
    local build="$BUILD/$PIXMAN_DIR"

    extract "$PIXMAN_ARCHIVE" "$src"

    echo "Building pixman..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$PIXMAN_INSTALL" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/pixman.log" 2>&1 || print_failed_and_exit "$LOG/pixman.log"
)

# Build cairo (dependency of pango)
build_cairo()
(
    local src="$SRC/$CAIRO_DIR"
    local build="$BUILD/$CAIRO_DIR"

    extract "$CAIRO_ARCHIVE" "$src"

    echo "Building cairo..."
    mkdir -p "$build"
    (
        cd "$build"

        pkg_config_libdir="$FREETYPE_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$EXPAT_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FONTCONFIG_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$PIXMAN_INSTALL/lib/pkgconfig"

        PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
        "$src/configure" --prefix="$CAIRO_INSTALL" --disable-shared --enable-static \
            --enable-png=no --enable-svg=no \
            --enable-interpreter=no --enable-trace=no
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/cairo.log" 2>&1 || print_failed_and_exit "$LOG/cairo.log"
)

# Build harfuzz (dependency of pango)
build_harfbuzz()
(
    local src="$SRC/$HARFBUZZ_DIR"
    local build="$BUILD/$HARFBUZZ_DIR"

    extract "$HARFBUZZ_ARCHIVE" "$src"
    # Don't build test and docs
    sed_i "s|SUBDIRS = src util test docs|SUBDIRS = src util|" "$src/Makefile.in"

    echo "Building harfbuzz..."
    mkdir -p "$build"
    (
        cd "$build"
        PKG_CONFIG_LIBDIR="$FREETYPE_INSTALL/lib/pkgconfig:$GLIB2_INSTALL/lib/pkgconfig" \
        "$src/configure" --prefix="$HARFBUZZ_INSTALL" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/harfbuzz.log" 2>&1 || print_failed_and_exit "$LOG/harfbuzz.log"
)

# Build pango
build_pango()
(
    local src="$SRC/$PANGO_DIR"
    local build="$BUILD/$PANGO_DIR"

    extract "$PANGO_ARCHIVE" "$src"
    # Don't build utils, tests, tools
    sed_i -E "/subdir\('(utils|tests|tools)'\)/d" "$src/meson.build"

    echo "Building pango..."
    mkdir -p "$build"
    (
        pkg_config_libdir="$CAIRO_INSTALL/lib/pkgconfig:$PIXMAN_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$EXPAT_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FONTCONFIG_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FREETYPE_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$HARFBUZZ_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$GLIB2_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$LIBFFI_INSTALL/lib/pkgconfig"

        PATH="$GLIB2_INSTALL/bin:$PATH" PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
        meson setup --prefix "$PANGO_INSTALL" --libdir=lib --buildtype plain \
            --default-library static --auto-features=disabled \
            -D introspection=false \
            "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"
    ) > "$LOG/pango.log" 2>&1 || print_failed_and_exit "$LOG/pango.log"
)

# Build python
build_python()
(
    local src="$SRC/$PYTHON_DIR"
    local build="$BUILD/$PYTHON_DIR"

    extract "$PYTHON_ARCHIVE" "$src"

    echo "Building python..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$PYTHON_INSTALL" --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/python.log" 2>&1 || print_failed_and_exit "$LOG/python.log"
)


# Run build functions.
build_expat
build_freetype2
build_util_linux
build_fontconfig
build_ghostscript
build_libffi
build_zlib
build_glib2
build_gmp
build_libtool
build_guile
build_pixman
build_cairo
build_harfbuzz
build_pango
build_python


echo "DONE"
exit 0
