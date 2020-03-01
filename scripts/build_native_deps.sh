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
#  * guile (version 2.2)
#    * gc
#    * gmp
#    * libffi
#    * libtool
#    * libunistring
#      * libiconv
#  * pango
#    * cairo
#      * fontconfig
#      * freetype2
#      * pixman
#      * zlib
#    * glib2
#    * harfbuzz
#  * python (version 2.7)

. "$(dirname $0)/tools.sh"
. "$(dirname $0)/native_deps.sh"

LOG="$DEPENDENCIES/log"
mkdir -p "$LOG"

NATIVE_TARGET="$(cc -dumpmachine)"
if [ -z "$CONFIGURE_HOST" ]; then
    # Use default native machine as host. Especially important for gmp which
    # tries to target the specific host CPU unless --host is given...
    CONFIGURE_HOST="--host=$NATIVE_TARGET"
fi

echo "Downloading source code..."
download "$EXPAT_URL" "$EXPAT_ARCHIVE"
download "$FREETYPE_URL" "$FREETYPE_ARCHIVE"
download "$UTIL_LINUX_URL" "$UTIL_LINUX_ARCHIVE"
download "$FONTCONFIG_URL" "$FONTCONFIG_ARCHIVE"

download "$GHOSTSCRIPT_URL" "$GHOSTSCRIPT_ARCHIVE"

download "$LIBFFI_URL" "$LIBFFI_ARCHIVE"
download "$ZLIB_URL" "$ZLIB_ARCHIVE"
download "$GLIB2_URL" "$GLIB2_ARCHIVE"

download "$GC_URL" "$GC_ARCHIVE"
download "$GMP_URL" "$GMP_ARCHIVE"
download "$LIBTOOL_URL" "$LIBTOOL_ARCHIVE"
download "$LIBICONV_URL" "$LIBICONV_ARCHIVE"
download "$LIBUNISTRING_URL" "$LIBUNISTRING_ARCHIVE"
download "$GUILE_URL" "$GUILE_ARCHIVE"

download "$PIXMAN_URL" "$PIXMAN_ARCHIVE"
download "$CAIRO_URL" "$CAIRO_ARCHIVE"
download "$HARFBUZZ_URL" "$HARFBUZZ_ARCHIVE"
download "$PANGO_URL" "$PANGO_ARCHIVE"

download "$PYTHON_URL" "$PYTHON_ARCHIVE"

echo ""

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
        "$src/configure" $CONFIGURE_HOST --prefix="$EXPAT_INSTALL" \
            --disable-shared --enable-static \
            --without-xmlwf --without-examples --without-tests
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/expat.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/expat.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$FREETYPE_INSTALL" \
            --disable-shared --enable-static \
            --with-zlib=no --with-bzip2=no --with-png=no --with-harfbuzz=no
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/freetype2.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/freetype2.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$UTIL_LINUX_INSTALL" \
            --disable-shared --enable-static \
            --disable-all-programs --enable-libuuid
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/util-linux.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/util-linux.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$FONTCONFIG_INSTALL" \
            --disable-shared --enable-static --disable-docs
        $MAKE -j$PROCS
        $MAKE install

        # Patch pkgconfig file for static dependencies.
        sed_i -e "s|Requires:.*|& \\\\|" -e "s|Requires.private:||" \
            "$FONTCONFIG_INSTALL/lib/pkgconfig/fontconfig.pc"
    ) > "$LOG/fontconfig.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/fontconfig.log"
)

# Build ghostscript
build_ghostscript()
(
    local src="$SRC/$GHOSTSCRIPT_DIR"
    local build="$BUILD/$GHOSTSCRIPT_DIR"

    extract "$GHOSTSCRIPT_ARCHIVE" "$src"
    if [ -n "$MINGW_CROSS" ]; then
        # Do not pass -rdynamic
        sed_i 's|DYNAMIC_LIBS="-rdynamic"|DYNAMIC_LIBS=""|g' "$src/configure"
        # Fix invocation of configure for AUX
        sed_i 's|../\$0|\$0|' "$src/configure"
        # Remove function call that is win32 specific
        sed_i 's|gp_local_arg_encoding_get_codepoint|NULL|g' "$src/psi/psapi.c"
    fi

    echo "Building ghostscript..."
    mkdir -p "$build"
    (
        cd "$build"

        local gs_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure.
            local gs_extra_flags="--build=$NATIVE_TARGET --with-exe-ext=.exe "
            local gs_extra_flags="$gs_extra_flags --with-arch_h=$src/arch/windows-x64-msvc.h"
            local gs_extra_flags="$gs_extra_flags CCAUX=cc CFLAGS=-DHAVE_SYS_TIMES_H=0 CFLAGSAUX= "
        fi

        PKG_CONFIG_LIBDIR="$FONTCONFIG_INSTALL/lib/pkgconfig:$FREETYPE_INSTALL/lib/pkgconfig" \
        "$src/configure" $CONFIGURE_HOST --prefix="$GHOSTSCRIPT_INSTALL" \
            --disable-dynamic --with-drivers=PNG,PS \
            --without-libidn --without-libpaper --without-libtiff --without-pdftoraster \
            --without-ijs --without-luratech --without-jbig2dec --without-cal \
            --disable-cups --disable-openjpeg --disable-gtk $gs_extra_flags
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/ghostscript.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/ghostscript.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$LIBFFI_INSTALL" \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libffi.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/libffi.log"
)

# Build zlib (dependency of glib2)
build_zlib()
(
    local src="$SRC/$ZLIB_DIR"
    local build="$BUILD/$ZLIB_DIR"

    extract "$ZLIB_ARCHIVE" "$src"
    if [ -n "$MINGW_CROSS" ]; then
        # Enable cross-compilation for mingw.
        sed_i 's|leave 1||g' "$src/configure"
    fi

    echo "Building zlib..."
    mkdir -p "$build"
    (
        cd "$build"

        if [ -n "$MINGW_CROSS" ]; then
            # Enable cross compilation
            export CHOST=$MINGW_TARGET
        fi

        "$src/configure" --prefix="$ZLIB_INSTALL" --static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/zlib.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/zlib.log"
)

# Build glib2
build_glib2()
(
    local src="$SRC/$GLIB2_DIR"
    local build="$BUILD/$GLIB2_DIR"

    extract "$GLIB2_ARCHIVE" "$src"
    # Don't build tests
    sed_i "s|build_tests =.*|build_tests = false|" "$src/meson.build"
    # Don't build gio, fuzzing
    sed_i -E "/subdir\('(gio|fuzzing)'\)/d" "$src/meson.build"
    # Don't build gobject-query
    sed_i "/gobject-query/,+3d" "$src/gobject/meson.build"

    echo "Building glib2..."
    mkdir -p "$build"
    (
        local glib2_library="static"
        local glib2_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # The libraries rely on DllMain which doesn't work with static.
            local glib2_library="shared"
            # Pass some extra flags to meson.
            local glib2_extra_flags="$MESON_CROSS_ARG"
        fi

        PKG_CONFIG_LIBDIR="$LIBFFI_INSTALL/lib/pkgconfig:$ZLIB_INSTALL/lib/pkgconfig" \
        meson setup --prefix "$GLIB2_INSTALL" --libdir=lib --buildtype plain \
            --default-library $glib2_library --auto-features=disabled \
            -D internal_pcre=true -D libmount=false -D xattr=false \
            $glib2_extra_flags "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"
    ) > "$LOG/glib2.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/glib2.log"
)

# Build gc (dependency of guile)
build_gc()
(
    local src="$SRC/$GC_DIR"
    local build="$BUILD/$GC_DIR"

    extract "$GC_ARCHIVE" "$src"

    echo "Building gc..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_HOST --prefix="$GC_INSTALL" \
            --disable-shared --enable-static --with-pic \
            --disable-threads --disable-docs
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/gc.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/gc.log"
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

        local gmp_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure.
            local gmp_extra_flags="CC_FOR_BUILD=cc "
        fi

        "$src/configure" $CONFIGURE_HOST --prefix="$GMP_INSTALL" \
            --disable-shared --enable-static --with-pic $gmp_extra_flags
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/gmp.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/gmp.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$LIBTOOL_INSTALL" \
            --disable-shared --enable-static --with-pic
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libtool.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/libtool.log"
)

# Build libiconv (dependency of libunistring)
build_libiconv()
(
    local src="$SRC/$LIBICONV_DIR"
    local build="$BUILD/$LIBICONV_DIR"

    extract "$LIBICONV_ARCHIVE" "$src"

    echo "Building libiconv..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_HOST --prefix="$LIBICONV_INSTALL" \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libiconv.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/libiconv.log"
)

# Build libunistring (dependency of guile)
build_libunistring()
(
    local src="$SRC/$LIBUNISTRING_DIR"
    local build="$BUILD/$LIBUNISTRING_DIR"

    extract "$LIBUNISTRING_ARCHIVE" "$src"

    echo "Building libunistring..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_HOST --prefix="$LIBUNISTRING_INSTALL" \
            --disable-shared --enable-static \
            --with-libiconv-prefix="$LIBICONV_INSTALL"
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libunistring.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/libunistring.log"
)

# Build guile
build_guile()
(
    local src="$SRC/$GUILE_DIR"
    local build="$BUILD/$GUILE_DIR"

    extract "$GUILE_ARCHIVE" "$src"
    if [ -n "$MINGW_CROSS" ]; then
        # Remove SCM_IMPORT from source file for guile executable, leads to
        # linking errors.
        sed_i "/SCM_IMPORT/d" "$src/libguile/guile.c"

        # Fix compilation errors:
        #  * linking error
        sed_i "/gethostname_used_without_requesting_/d" "$src/lib/unistd.in.h"
        #  * different header on mingw
        sed_i "s|sys/select.h|winsock2.h|" "$src/libguile/iselect.h"
        #  * different typedef on mingw
        sed_i "s| sigset_t| _sigset_t|g" "$src/libguile/null-threads.h"
        #  * missing function on mingw
        sed_i "s|return sigprocmask.*|return 0;|" "$src/libguile/null-threads.h"
        #  * error in cmath when using ::copysign
        sed_i "/copysign/d" "$src/libguile/numbers.h"
        #  * "conflicting types".
        sed_i "s|int start_child|pid_t start_child|" "$src/libguile/posix-w32.h"
    fi

    echo "Building guile..."
    mkdir -p "$build"
    (
        cd "$build"

        local guile_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure. Need explicit --build option
            # to enforce cross compilation.
            local guile_extra_flags="--build=$NATIVE_TARGET CC_FOR_BUILD=cc GUILE_FOR_BUILD=$NATIVE_GUILE_INSTALL/bin/guile"
        fi

        PKG_CONFIG_LIBDIR="$GC_INSTALL/lib/pkgconfig:$LIBFFI_INSTALL/lib/pkgconfig" \
        "$src/configure" $CONFIGURE_HOST --prefix="$GUILE_INSTALL" \
            --disable-shared --enable-static --with-pic \
            --without-threads --disable-networking \
            --disable-error-on-warning $guile_extra_flags \
            --with-libiconv-prefix="$LIBICONV_INSTALL" \
            --with-libunistring-prefix="$LIBUNISTRING_INSTALL" \
            --with-libgmp-prefix="$GMP_INSTALL" \
            --with-libltdl-prefix="$LIBTOOL_INSTALL"
        $MAKE -j$PROCS
        $MAKE install

        # Patch pkgconfig file for static dependencies.
        sed_i -e "s|Libs:.*|& \\\\|" -e "s|Libs.private:||" \
            "$GUILE_INSTALL/lib/pkgconfig/guile-$GUILE_VERSION_MAJOR.pc"
    ) > "$LOG/guile.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/guile.log"
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
        "$src/configure" $CONFIGURE_HOST --prefix="$PIXMAN_INSTALL" \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/pixman.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/pixman.log"
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

        local cairo_library_flags="--disable-shared --enable-static"
        local cairo_extra_ldflags=""
        if [ -n "$MINGW_CROSS" ]; then
            # The library relies on DllMain which doesn't work with static.
            local cairo_library_flags="--enable-shared --disable-static lt_cv_deplibs_check_method=pass_all"
            local cairo_extra_ldflags="-lssp"
        fi

        PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
        "$src/configure" $CONFIGURE_HOST --prefix="$CAIRO_INSTALL" \
            $cairo_library_flags \
            --enable-xlib=no --enable-xlib-xrender=no --enable-xcb=no \
            --enable-xlib-xcb=no --enable-xcb-shm=no --enable-qt=no \
            --enable-quartz=no --enable-quartz-font=no --enable-quartz-image=no \
            --enable-png=no --enable-svg=no \
            --enable-interpreter=no --enable-trace=no \
            CPPFLAGS="-I$ZLIB_INSTALL/include" \
            LDFLAGS="-L$ZLIB_INSTALL/lib $cairo_extra_ldflags"
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/cairo.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/cairo.log"
)

# Build harfuzz (dependency of pango)
build_harfbuzz()
(
    local src="$SRC/$HARFBUZZ_DIR"
    local build="$BUILD/$HARFBUZZ_DIR"

    extract "$HARFBUZZ_ARCHIVE" "$src"
    # Don't build util, test, docs
    sed_i "s|SUBDIRS = src util test docs|SUBDIRS = src|" "$src/Makefile.in"

    echo "Building harfbuzz..."
    mkdir -p "$build"
    (
        cd "$build"
        PKG_CONFIG_LIBDIR="$FREETYPE_INSTALL/lib/pkgconfig:$GLIB2_INSTALL/lib/pkgconfig" \
        "$src/configure" $CONFIGURE_HOST --prefix="$HARFBUZZ_INSTALL" \
            --disable-shared --enable-static --with-icu=no
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/harfbuzz.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/harfbuzz.log"
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
        local pango_library="static"
        local pango_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # We need to build glib2 and cairo as dynamic libraries, so pango
            # also needs to be one for linking.
            local pango_library="shared"
            # Pass some extra flags to meson.
            local pango_extra_flags="$MESON_CROSS_ARG"
        fi

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
            --default-library "$pango_library" --auto-features=disabled \
            -D introspection=false \
            $pango_extra_flags "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"
    ) > "$LOG/pango.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/pango.log"
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
        "$src/configure" --prefix="$PYTHON_INSTALL" \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/python.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/python.log"
)


# Run build functions.
fns=""
fns="$fns build_expat"
fns="$fns build_freetype2"
if [ -z "$MINGW_CROSS" ]; then
    fns="$fns build_util_linux"
fi
fns="$fns build_fontconfig"
fns="$fns build_ghostscript"
fns="$fns build_libffi"
fns="$fns build_zlib"
fns="$fns build_glib2"
fns="$fns build_gc"
fns="$fns build_gmp"
fns="$fns build_libtool"
fns="$fns build_libiconv"
fns="$fns build_libunistring"
fns="$fns build_guile"
fns="$fns build_pixman"
fns="$fns build_cairo"
fns="$fns build_harfbuzz"
fns="$fns build_pango"
if [ -z "$MINGW_CROSS" ]; then
    fns="$fns build_python"
fi

for fn in $fns; do
    $fn
    echo
done


echo "DONE"
exit 0
