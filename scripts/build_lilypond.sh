#!/bin/sh

set -e

if [ -z "$LILYPOND_TAR" ]; then
    echo "Point LILYPOND_TAR to LilyPond tarball" >&2
    exit 1
fi

. "$(dirname $0)/native_deps.sh"
. "$(dirname $0)/tools.sh"

if [ -n "$MINGW_CROSS" ]; then
    # Build below mingw/
    ROOT="$MINGW_ROOT"
    # Use native Python.
    PYTHON_INSTALL="$NATIVE_PYTHON_INSTALL"
else
    # Not cross-compiling, so just empty.
    CONFIGURE_HOST=""
fi

LILYPOND="$ROOT/lilypond"
LILYPOND_SRC="$LILYPOND/src"
LILYPOND_BUILD="$LILYPOND/build"
LILYPOND_INSTALL="$LILYPOND/install"

if [ -z "$FLEXLEXER_DIR" ]; then
    FLEXLEXER_DIR="not-found"
    # Guess the default paths.
    for d in /usr/include /include; do
        if [ -f "$d/FlexLexer.h" ]; then
            FLEXLEXER_DIR="$d"
            break
        fi
    done
fi
if [ ! -f "$FLEXLEXER_DIR/FlexLexer.h" ]; then
    echo "Could not find FlexLexer.h, please set FLEXLEXER_DIR!" >&2
    exit 1
fi
# Copy header to avoid a global -I/usr/include.
LILYPOND_FLEXLEXER="$LILYPOND/FlexLexer"
mkdir -p "$LILYPOND_FLEXLEXER"
cp "$FLEXLEXER_DIR/FlexLexer.h" "$LILYPOND_FLEXLEXER"

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

    pkg_config_libdir="$EXPAT_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$LIBFFI_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$FONTCONFIG_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$FREETYPE_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$GLIB2_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$GC_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$GUILE_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$HARFBUZZ_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$FRIBIDI_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$PANGO_INSTALL/lib/pkgconfig"
    pkg_config_libdir="$pkg_config_libdir:$UTIL_LINUX_INSTALL/lib/pkgconfig"

    PKG_CONFIG_LIBDIR="$pkg_config_libdir" \
    GHOSTSCRIPT="$GHOSTSCRIPT_INSTALL/bin/gs" \
    GUILE="$GUILE_INSTALL/bin/guile" PYTHON="$PYTHON_INSTALL/bin/python3" \
    "$LILYPOND_SRC/configure" $CONFIGURE_HOST --prefix="$LILYPOND_INSTALL" \
        --disable-documentation --enable-static-gxx \
        CPPFLAGS="-isystem $LILYPOND_FLEXLEXER -DSTATIC"

    $MAKE -j$PROCS

    if [ -n "$MINGW_CROSS" ]; then
        # Workaround broken build system for now.
        (cd "$LILYPOND_BUILD/lily/out/" && mv lilypond.exe lilypond)
    fi

    $MAKE install
) > "$LILYPOND/build.log" 2>&1 &
wait $! || print_failed_and_exit "$LILYPOND/build.log"

echo
echo "DONE"
exit 0
