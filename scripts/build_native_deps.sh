#!/bin/sh

set -e

# Build dependencies for LilyPond needed at runtime:
#  * fontconfig
#    * expat
#    * freetype2
#    * util-linux (for libuuid, except mingw)
#  * ghostscript
#    * fontconfig
#    * freetype2
#  * glib2
#    * gettext-runtime (for FreeBSD and macOS)
#    * libffi
#    * zlib
#  * guile (version 2.2)
#    * gc
#    * gettext-runtime (for macOS)
#    * gmp
#    * libffi
#    * libtool
#    * libunistring
#      * libiconv (for mingw)
#  * pango
#    * fontconfig
#    * freetype2
#    * fribidi
#    * gettext-runtime (for macOS)
#    * glib2
#    * harfbuzz
#  * python

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
CONFIGURE_TARGETS="--build=$NATIVE_TARGET $CONFIGURE_HOST"

echo "Downloading source code..."
download "$EXPAT_URL" "$EXPAT_ARCHIVE"
download "$FREETYPE_URL" "$FREETYPE_ARCHIVE"
download "$UTIL_LINUX_URL" "$UTIL_LINUX_ARCHIVE"
download "$FONTCONFIG_URL" "$FONTCONFIG_ARCHIVE"

download "$GHOSTSCRIPT_URL" "$GHOSTSCRIPT_ARCHIVE"

download "$GETTEXT_URL" "$GETTEXT_ARCHIVE"
download "$LIBFFI_URL" "$LIBFFI_ARCHIVE"
download "$ZLIB_URL" "$ZLIB_ARCHIVE"
download "$GLIB2_URL" "$GLIB2_ARCHIVE"

download "$GC_URL" "$GC_ARCHIVE"
download "$GMP_URL" "$GMP_ARCHIVE"
download "$LIBTOOL_URL" "$LIBTOOL_ARCHIVE"
download "$LIBICONV_URL" "$LIBICONV_ARCHIVE"
download "$LIBUNISTRING_URL" "$LIBUNISTRING_ARCHIVE"
download "$GUILE_URL" "$GUILE_ARCHIVE"

download "$HARFBUZZ_URL" "$HARFBUZZ_ARCHIVE"
download "$FRIBIDI_URL" "$FRIBIDI_ARCHIVE"
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$EXPAT_INSTALL" \
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$FREETYPE_INSTALL" \
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
    if [ "$uname" = "Darwin" ] || [ "$uname" = "FreeBSD" ]; then
        # Fix build.
        sed_i "s|lib/libcommon_la-procutils.lo ||" "$src/Makefile.in"
    fi

    echo "Building util-linux..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_TARGETS --prefix="$UTIL_LINUX_INSTALL" \
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$FONTCONFIG_INSTALL" \
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
    rm -rf "$src/tesseract" "$src/leptonica"
    if [ -n "$MINGW_CROSS" ]; then
        # Fix function definition, see https://bugs.ghostscript.com/show_bug.cgi?id=699331
        sed_i -e 's|gp_local_arg_encoding_get_codepoint(FILE|gp_local_arg_encoding_get_codepoint(gp_file|' \
              -e 's| fgetc(file| gp_fgetc(file|g' "$src/base/gp_unix.c"
    fi

    echo "Building ghostscript..."
    mkdir -p "$build"
    (
        cd "$build"

        local gs_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure.
            local gs_extra_flags="CFLAGS=-DHAVE_SYS_TIMES_H=0"
        fi

        PKG_CONFIG_LIBDIR="$FONTCONFIG_INSTALL/lib/pkgconfig:$FREETYPE_INSTALL/lib/pkgconfig" \
        "$src/configure" $CONFIGURE_TARGETS --prefix="$GHOSTSCRIPT_INSTALL" \
            --disable-dynamic --with-drivers=PNG,PS \
            --without-libidn --without-libpaper --without-libtiff --without-pdftoraster \
            --without-ijs --without-jbig2dec --without-cal \
            --disable-fontconfig --disable-dbus --disable-cups \
            --disable-openjpeg --disable-gtk $gs_extra_flags
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/ghostscript.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/ghostscript.log"
)

# Build gettext (dependency of glib2 on FreeBSD and macOS)
build_gettext()
(
    local src="$SRC/$GETTEXT_DIR"
    local build="$BUILD/$GETTEXT_DIR"

    extract "$GETTEXT_ARCHIVE" "$src"
    # localcharset.c defines locale_charset, which is also provided by
    # Guile. However, Guile has a modification to this file so we really
    # need to build that version.
    sed_i "s|localcharset.lo||" "$src/gettext-runtime/intl/Makefile.in"
    sed_i "s|locale_charset ()|NULL|" "$src/gettext-runtime/intl/dcigettext.c"

    echo "Building gettext..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/gettext-runtime/configure" $CONFIGURE_TARGETS \
            --prefix="$GETTEXT_INSTALL" --disable-shared --enable-static \
            --disable-java
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/gettext.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/gettext.log"
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$LIBFFI_INSTALL" \
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
    # Don't build gobject-query (delete all three lines)
    sed_i "/gobject-query/{N;N;N;d;}" "$src/gobject/meson.build"
    # Fix detection of libintl on macOS
    sed_i "s|'ngettext'|'ngettext', args : osx_ldflags|" "$src/meson.build"

    echo "Building glib2..."
    mkdir -p "$build"
    (
        local glib2_library="static"
        local glib2_extra_flags=""
        if [ "$uname" = "Darwin" ] || [ "$uname" = "FreeBSD" ]; then
            # Make meson find libintl.
            export CPATH="$GETTEXT_INSTALL/include"
            export LIBRARY_PATH="$GETTEXT_INSTALL/lib"
        fi
        if [ -n "$MINGW_CROSS" ]; then
            # The libraries rely on DllMain which doesn't work with static.
            local glib2_library="shared"
            # Pass some extra flags to meson.
            local glib2_extra_flags="$MESON_CROSS_ARG"
        fi

        PKG_CONFIG_LIBDIR="$LIBFFI_INSTALL/lib/pkgconfig:$ZLIB_INSTALL/lib/pkgconfig" \
        meson setup --prefix "$GLIB2_INSTALL" --libdir=lib --buildtype release \
            --default-library $glib2_library --auto-features=disabled \
            -D internal_pcre=true -D libmount=disabled -D tests=false -D xattr=false \
            $glib2_extra_flags "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"

        # Patch pkgconfig file for static dependencies on macOS to include
        # the -framework definitions.
        if [ "$uname" = "Darwin" ]; then
            sed_i -e "s|Libs:.*|& \\\\|" -e "s|Libs.private:||" \
                "$GLIB2_INSTALL/lib/pkgconfig/glib-2.0.pc"
        fi
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$GC_INSTALL" \
            --disable-shared --enable-static --disable-docs \
            --enable-large-config --with-libatomic-ops=none
        $MAKE -j$PROCS
        $MAKE install

        # Patch pkgconfig file to include -pthread.
        sed_i "s|Cflags:.*|& -pthread|" "$GC_INSTALL/lib/pkgconfig/bdw-gc.pc"
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

        "$src/configure" $CONFIGURE_TARGETS --prefix="$GMP_INSTALL" \
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
        "$src/configure" $CONFIGURE_TARGETS --prefix="$LIBTOOL_INSTALL" \
            --disable-shared --enable-static --with-pic
        $MAKE -j$PROCS
        $MAKE install
    ) > "$LOG/libtool.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/libtool.log"
)

# Build libiconv (dependency of libunistring for mingw)
build_libiconv()
(
    local src="$SRC/$LIBICONV_DIR"
    local build="$BUILD/$LIBICONV_DIR"

    extract "$LIBICONV_ARCHIVE" "$src"

    echo "Building libiconv..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_TARGETS --prefix="$LIBICONV_INSTALL" \
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

        local libunistring_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure.
            local libunistring_extra_flags="--with-libiconv-prefix=$LIBICONV_INSTALL"
        fi

        "$src/configure" $CONFIGURE_TARGETS --prefix="$LIBUNISTRING_INSTALL" \
            --disable-shared --enable-static \
            "$libunistring_extra_flags"
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
    # Fix configure on CentOS to not look in lib64.
    sed_i "s|=lib64|=lib|g" "$src/configure"
    if [ "$uname" = "Darwin" ] || [ "$uname" = "FreeBSD" ]; then
        # Fix non-portable invocation of inplace sed.
        sed_i "s|\$(SED) -i|\$(SED)|" "$src/libguile/Makefile.in"
    fi
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
        if [ "$uname" = "Darwin" ]; then
            # Pass some extra flags to configure.
            local guile_extra_flags="--with-libintl-prefix=$GETTEXT_INSTALL"
            export LDFLAGS="-Wl,-framework -Wl,CoreFoundation"
        fi
        if [ -n "$MINGW_CROSS" ]; then
            # Pass some extra flags to configure. Need explicit --build option
            # to enforce cross compilation.
            local guile_extra_flags="--build=$NATIVE_TARGET CC_FOR_BUILD=cc GUILE_FOR_BUILD=$NATIVE_GUILE_INSTALL/bin/guile --with-libiconv-prefix=$LIBICONV_INSTALL"
        fi

        PKG_CONFIG_LIBDIR="$GC_INSTALL/lib/pkgconfig:$LIBFFI_INSTALL/lib/pkgconfig" \
        "$src/configure" $CONFIGURE_TARGETS --prefix="$GUILE_INSTALL" \
            --disable-shared --enable-static --with-pic \
            --without-threads --disable-networking \
            --disable-error-on-warning $guile_extra_flags \
            --with-libunistring-prefix="$LIBUNISTRING_INSTALL" \
            --with-libgmp-prefix="$GMP_INSTALL" \
            --with-libltdl-prefix="$LIBTOOL_INSTALL" \
            ac_cv_search_crypt=no
        $MAKE -j$PROCS
        $MAKE install

        # Patch pkgconfig file for static dependencies. For CentOS, explicitly
        # mention the static library or pkg-config will reorder the libraries.
        sed_i -e "s|Libs:.*|& \\\\|" -e "s|Libs.private:||" \
              -e "s|-lguile-$GUILE_VERSION_MAJOR|\${libdir}/libguile-$GUILE_VERSION_MAJOR.a|" \
            "$GUILE_INSTALL/lib/pkgconfig/guile-$GUILE_VERSION_MAJOR.pc"
    ) > "$LOG/guile.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/guile.log"
)

# Build harfuzz (dependency of pango)
build_harfbuzz()
(
    local src="$SRC/$HARFBUZZ_DIR"
    local build="$BUILD/$HARFBUZZ_DIR"

    extract "$HARFBUZZ_ARCHIVE" "$src"

    echo "Building harfbuzz..."
    mkdir -p "$build"
    (
        local harfbuzz_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            local harfbuzz_extra_flags="$MESON_CROSS_ARG"
        fi

        cd "$build"
        PKG_CONFIG_LIBDIR="$FREETYPE_INSTALL/lib/pkgconfig" \
        meson setup --prefix "$HARFBUZZ_INSTALL" --libdir=lib --buildtype release \
            --default-library static --auto-features=disabled -D tests=disabled \
            -D freetype=enabled $harfbuzz_extra_flags "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"

        if [ "$uname" = "FreeBSD" ]; then
            # Move pkgconfig files where we expect them...
            mv "$HARFBUZZ_INSTALL/libdata/pkgconfig" "$HARFBUZZ_INSTALL/lib/pkgconfig"
        fi
        # Patch pkgconfig file for static dependencies.
        sed_i "s|Requires.private:|Requires:|" \
            "$HARFBUZZ_INSTALL/lib/pkgconfig/harfbuzz.pc"
    ) > "$LOG/harfbuzz.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/harfbuzz.log"
)

# Build fribidi (dependency of pango)
build_fribidi()
(
    local src="$SRC/$FRIBIDI_DIR"
    local build="$BUILD/$FRIBIDI_DIR"

    extract "$FRIBIDI_ARCHIVE" "$src"

    echo "Building fribidi..."
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" $CONFIGURE_TARGETS --prefix="$FRIBIDI_INSTALL" \
            --disable-shared --enable-static
        $MAKE -j$PROCS
        $MAKE install
        # Patch pkgconfig file for static dependencies.
        sed_i -e "s|Cflags:.*|& \\\\|" -e "s|CFLAGS.private:||" \
            "$FRIBIDI_INSTALL/lib/pkgconfig/fribidi.pc"
    ) > "$LOG/fribidi.log" 2>&1 &
    wait $! || print_failed_and_exit "$LOG/fribidi.log"
)

# Build pango
build_pango()
(
    local src="$SRC/$PANGO_DIR"
    local build="$BUILD/$PANGO_DIR"

    extract "$PANGO_ARCHIVE" "$src"
    # Don't build utils, examples, tests, tools
    sed_i -E "/subdir\('(utils|examples|tests|tools)'\)/d" "$src/meson.build"

    echo "Building pango..."
    mkdir -p "$build"
    (
        local pango_extra_flags=""
        if [ -n "$MINGW_CROSS" ]; then
            local pango_extra_flags="$MESON_CROSS_ARG"
        fi

        pkg_config_libdir="$EXPAT_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FONTCONFIG_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FREETYPE_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$HARFBUZZ_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$FRIBIDI_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$GLIB2_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$LIBFFI_INSTALL/lib/pkgconfig"
        pkg_config_libdir="$pkg_config_libdir:$ZLIB_INSTALL/lib/pkgconfig"

        PATH="$GLIB2_INSTALL/bin:$PATH" PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
        meson setup --prefix "$PANGO_INSTALL" --libdir=lib --buildtype release \
            --default-library static --auto-features=disabled \
            -D fontconfig=enabled -D freetype=enabled \
            $pango_extra_flags "$src" "$build"
        ninja -C "$build" -j$PROCS
        meson install -C "$build"

        if [ "$uname" = "FreeBSD" ]; then
            # Move pkgconfig files where we expect them...
            mv "$PANGO_INSTALL/libdata/pkgconfig" "$PANGO_INSTALL/lib/pkgconfig"
        fi
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

        if [ "$uname" = "Darwin" ]; then
            # Make the build system find libintl.
            export CPATH="$GETTEXT_INSTALL/include"
            export LIBRARY_PATH="$GETTEXT_INSTALL/lib"
            # Fix linking static libintl from static libpython.
            export LDFLAGS="-lintl -liconv"
        fi

        "$src/configure" --prefix="$PYTHON_INSTALL" \
            --disable-shared --enable-static \
            ac_cv_search_crypt=no ac_cv_search_crypt_r=no
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
if [ "$uname" = "Darwin" ] || [ "$uname" = "FreeBSD" ]; then
    fns="$fns build_gettext"
fi
fns="$fns build_libffi"
fns="$fns build_zlib"
fns="$fns build_glib2"
fns="$fns build_gc"
fns="$fns build_gmp"
fns="$fns build_libtool"
if [ -n "$MINGW_CROSS" ]; then
    fns="$fns build_libiconv"
fi
fns="$fns build_libunistring"
fns="$fns build_guile"
fns="$fns build_harfbuzz"
fns="$fns build_fribidi"
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
