#!/bin/sh

set -e
umask 022

. "$(dirname $0)/mingw.sh"
DEPENDENCIES_ROOT="$MINGW_ROOT"
. "$(dirname $0)/native_deps.sh"

PACKAGE_DIR="$MINGW_ROOT/package"
LILYPOND_DIR="$PACKAGE_DIR/lilypond"
LICENSES_DIR="$LILYPOND_DIR/licenses"
LILYPOND_SRC="$MINGW_ROOT/lilypond/src"
LILYPOND_INSTALL="$MINGW_ROOT/lilypond/install"

MINGW_STRIP="$MINGW_TOOLCHAIN_INSTALL/bin/$MINGW_TARGET-strip"

PYTHON_SCRIPTS="abc2ly convert-ly etf2ly lilymidi lilypond-book lilysong midi2ly musicxml2ly"
GUILE_SCRIPTS="lilypond-invoke-editor"

LILYPOND_MINGW_ZIP="lilypond-mingw-x86_64.zip"
LILYPOND_MINGW_FULL_ZIP="lilypond-mingw-x86_64-full.zip"

PYTHON_EMBED_ARCHIVE="python-$PYTHON_VERSION-embed-amd64.zip"
PYTHON_EMBED_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_EMBED_ARCHIVE"
PYTHON_EMBED_DIR="python-$PYTHON_VERSION-embed-amd64"

download "$PYTHON_EMBED_URL" "$PYTHON_EMBED_ARCHIVE"
if [ -d "$MINGW_ROOT/$PYTHON_EMBED_DIR" ]; then
    echo "'$PYTHON_EMBED_ARCHIVE' already extracted!"
else
    echo "Extracting '$PYTHON_EMBED_ARCHIVE'..."
    (
        mkdir -p "$MINGW_ROOT/$PYTHON_EMBED_DIR"
        cd "$MINGW_ROOT/$PYTHON_EMBED_DIR"
        unzip -q "$DOWNLOADS/$PYTHON_EMBED_ARCHIVE"
    )
fi

echo "Creating '$LILYPOND_MINGW_ZIP'..."

rm -rf "$PACKAGE_DIR"
rm -f "$LILYPOND_MINGW_ZIP"

mkdir -p "$LILYPOND_DIR"
for dir in bin etc lib share; do
    mkdir "$LILYPOND_DIR/$dir"
done

# Copy all of LilyPond.
cp -RL "$LILYPOND_INSTALL"/* "$LILYPOND_DIR"
"$MINGW_STRIP" "$LILYPOND_DIR/bin/lilypond.exe"

# Copy required libraries.
for lib in libglib-2.0-0.dll libgobject-2.0-0.dll libintl.dll; do
    cp "$GLIB2_INSTALL/bin/$lib" "$LILYPOND_DIR/bin"
done

# Copy configuration files for Fontconfig.
cp -RL "$FONTCONFIG_INSTALL/etc/fonts" "$LILYPOND_DIR/etc/"
sed_i "\\|$FONTCONFIG_INSTALL|d" "$LILYPOND_DIR/etc/fonts/fonts.conf"

# Copy needed files for Guile. Source files in share/ should go before ccache
# to avoid warnings.
for d in share lib; do
    cp -RL "$GUILE_INSTALL/$d/guile" "$LILYPOND_DIR/$d/guile"
done

# Copy Ghostscript binary and spawn helpers from glib2.
cp "$GHOSTSCRIPT_INSTALL/bin/gs.exe" "$LILYPOND_DIR/bin"
"$MINGW_STRIP" "$LILYPOND_DIR/bin/gs.exe"
for s in gspawn-win64-helper.exe gspawn-win64-helper-console.exe; do
    cp "$GLIB2_INSTALL/bin/$s" "$LILYPOND_DIR/bin"
    "$MINGW_STRIP" "$LILYPOND_DIR/bin/$s"
done

# Strip all libraries.
"$MINGW_STRIP" "$LILYPOND_DIR/bin"/lib*.dll

# Copy files for relocation.
cp -RL "$ROOT/relocate" "$LILYPOND_DIR/etc"

# Add copyright notices and licenses.
# FIXME: De-duplicate from package_tar.sh
mkdir -p "$LICENSES_DIR"
cp "$SRC/$EXPAT_DIR/COPYING" "$LICENSES_DIR/$EXPAT_DIR.COPYING"
cp "$SRC/$FONTCONFIG_DIR/COPYING" "$LICENSES_DIR/$FONTCONFIG_DIR.COPYING"
cp "$SRC/$FREETYPE_DIR/docs/LICENSE.TXT" "$LICENSES_DIR/$FREETYPE_DIR.LICENSE.TXT"
cp "$SRC/$FREETYPE_DIR/docs/GPLv2.TXT" "$LICENSES_DIR/$FREETYPE_DIR.GPLv2.TXT"
cp "$SRC/$FRIBIDI_DIR/COPYING" "$LICENSES_DIR/$FRIBIDI_DIR.COPYING"
tail -n48 "$SRC/$GC_DIR/README.md" > "$LICENSES_DIR/$GC_DIR.README"
cp "$SRC/$GHOSTSCRIPT_DIR/LICENSE" "$LICENSES_DIR/$GHOSTSCRIPT_DIR.LICENSE"
cp "$SRC/$GHOSTSCRIPT_DIR/doc/COPYING" "$LICENSES_DIR/$GHOSTSCRIPT_DIR.COPYING"
cp "$SRC/$GLIB2_DIR/COPYING" "$LICENSES_DIR/$GLIB2_DIR.COPYING"
head -n27 "$SRC/$GMP_DIR/README" > "$LICENSES_DIR/$GMP_DIR.README"
cp "$SRC/$GMP_DIR/COPYING" "$LICENSES_DIR/$GMP_DIR.COPYING"
cp "$SRC/$GUILE_DIR/LICENSE" "$LICENSES_DIR/$GUILE_DIR.LICENSE"
cp "$SRC/$GUILE_DIR/COPYING.LESSER" "$LICENSES_DIR/$GUILE_DIR.COPYING.LESSER"
cp "$SRC/$HARFBUZZ_DIR/COPYING" "$LICENSES_DIR/$HARFBUZZ_DIR.COPYING"
cp "$SRC/$LIBFFI_DIR/LICENSE" "$LICENSES_DIR/$LIBFFI_DIR.LICENSE"
cp "$SRC/$LIBICONV_DIR/COPYING.LIB" "$LICENSES_DIR/$LIBICONV_DIR.COPYING.LIB"
cp "$SRC/$LIBTOOL_DIR/COPYING" "$LICENSES_DIR/$LIBTOOL_DIR.COPYING"
cp "$SRC/$LIBUNISTRING_DIR/COPYING.LIB" "$LICENSES_DIR/$LIBUNISTRING_DIR.COPYING.LIB"
cp "$SRC/$PANGO_DIR/COPYING" "$LICENSES_DIR/$PANGO_DIR.COPYING"
tail -n38 "$SRC/$ZLIB_DIR/README" > "$LICENSES_DIR/$ZLIB_DIR.README"

cp "$LILYPOND_SRC/COPYING" "$LICENSES_DIR/lilypond.COPYING"

# Create archive.
(
    cd "$PACKAGE_DIR"
    # Package lib/ last which contains the ccache for Guile.
    contents="$(ls -d lilypond/* | grep -v lilypond/lib) lilypond/lib"
    zip --recurse-paths --quiet "$ROOT/$LILYPOND_MINGW_ZIP" $contents
)

echo "Creating '$LILYPOND_MINGW_FULL_ZIP'..."

# Copy needed files from embeddable Python package.
cp "$MINGW_ROOT/$PYTHON_EMBED_DIR"/*.dll "$LILYPOND_DIR/bin"
cp "$MINGW_ROOT/$PYTHON_EMBED_DIR"/*.exe "$LILYPOND_DIR/bin"
cp "$MINGW_ROOT/$PYTHON_EMBED_DIR"/*.pyd "$LILYPOND_DIR/bin"
cp "$MINGW_ROOT/$PYTHON_EMBED_DIR"/*.zip "$LILYPOND_DIR/bin"
cp "$MINGW_ROOT/$PYTHON_EMBED_DIR/LICENSE.txt" "$LICENSES_DIR/$PYTHON_EMBED_DIR.LICENSE.txt"

# Create archive.
(
    cd "$PACKAGE_DIR"
    # Package lib/ last which contains the ccache for Guile.
    contents="$(ls -d lilypond/* | grep -v lilypond/lib) lilypond/lib"
    zip --recurse-paths --quiet "$ROOT/$LILYPOND_MINGW_FULL_ZIP" $contents
)
