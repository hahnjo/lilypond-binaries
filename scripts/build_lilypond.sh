#!/bin/sh

set -e

if [ -z "$LILYPOND_TAR" ]; then
    echo "Point LILYPOND_TAR to LilyPond tarball" >&2
    exit 1
fi

. "$(dirname $0)/native_deps.sh"
. "$(dirname $0)/tools.sh"

LILYPOND="$ROOT/lilypond"
LILYPOND_SRC="$LILYPOND/src"
LILYPOND_BUILD="$LILYPOND/build"
LILYPOND_INSTALL="$LILYPOND/install"

if [ ! $VERBOSE = 0 ]; then
    echo "Environment variables:"
    echo "LILYPOND=$LILYPOND"
    echo "LILYPOND_SRC=$LILYPOND_SRC"
    echo "LILYPOND_BUILD=$LILYPOND_BUILD"
    echo "LILYPOND_INSTALL=$LILYPOND_INSTALL"
    echo ""
fi

echo "Extracting '$LILYPOND_TAR'..."
mkdir -p "$LILYPOND_SRC"
tar -x -f "$LILYPOND_TAR" -C "$LILYPOND_SRC" --strip-components 1

# Enable dynamic relocation.
cat > "$LILYPOND_SRC/python/relocate-preamble.py.in" <<'EOF'
"""
bindir = os.path.abspath (os.path.dirname (sys.argv[0]))
for p in ['share', 'lib']:
    datadir = os.path.abspath (bindir + '/../%s/lilypond/@TOPLEVEL_VERSION@/python/' % p)
    sys.path.insert (0, datadir)
"""
EOF

echo "Building lilypond..."
mkdir -p "$LILYPOND_BUILD"
(
    cd "$LILYPOND_BUILD"

    # Load shared srfi modules.
    export LD_LIBRARY_PATH="$GUILE_INSTALL/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LDFLAGS="-Wl,--export-dynamic"

    pkg_config_libdir="$CAIRO_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$EXPAT_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$LIBFFI_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$FONTCONFIG_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$FREETYPE_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$GLIB2_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$HARFBUZZ_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$PANGO_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$PIXMAN_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"

    PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
    GHOSTSCRIPT="$GHOSTSCRIPT_INSTALL/bin/gs" \
    GUILE="$GUILE_INSTALL/bin/guile" GUILE_CONFIG="$GUILE_INSTALL/bin/guile-config" \
    PYTHON="$PYTHON_INSTALL/bin/python" PYTHON_CONFIG="$PYTHON_INSTALL/bin/python-config" \
    "$LILYPOND_SRC/configure" --prefix="$LILYPOND_INSTALL" --disable-documentation \
        --enable-static-gxx --enable-relocation

    $MAKE -j$PROCS
    $MAKE install
) > "$LILYPOND/build.log" 2>&1 &
wait $! || print_failed_and_exit "$LILYPOND/build.log"
