#!/bin/sh

set -e
umask 022

. "$(dirname $0)/mingw.sh"
DEPENDENCIES_ROOT="$MINGW_ROOT"
. "$(dirname $0)/native_deps.sh"

PACKAGE_DIR="$MINGW_ROOT/package"
LILYPOND_DIR="$PACKAGE_DIR/lilypond"
LILYPOND_INSTALL="$MINGW_ROOT/lilypond/install"

MINGW_STRIP="$MINGW_TOOLCHAIN_INSTALL/bin/$MINGW_TARGET-strip"

PYTHON_SCRIPTS="abc2ly convert-ly etf2ly lilymidi lilypond-book lilysong midi2ly musicxml2ly"
GUILE_SCRIPTS="lilypond-invoke-editor"

LILYPOND_MINGW_ZIP="lilypond-mingw-x86_64.zip"

echo "Creating '$LILYPOND_MINGW_ZIP'..."

rm -rf "$PACKAGE_DIR"
mkdir -p "$LILYPOND_DIR"
for dir in bin etc lib share; do
    mkdir "$LILYPOND_DIR/$dir"
done

# Copy all of LilyPond.
cp -r "$LILYPOND_INSTALL"/* "$LILYPOND_DIR"
"$MINGW_STRIP" "$LILYPOND_DIR/bin/lilypond.exe"

# Copy required libraries.
for lib in libglib-2.0-0.dll libgobject-2.0-0.dll libintl.dll; do
    cp "$GLIB2_INSTALL/bin/$lib" "$LILYPOND_DIR/bin"
done
for lib in libpango-1.0-0.dll libpangoft2-1.0-0.dll libfribidi-0.dll; do
    cp "$PANGO_INSTALL/bin/$lib" "$LILYPOND_DIR/bin"
done

# Copy configuration files for Fontconfig.
mkdir -p "$LILYPOND_DIR/etc/fonts"
cp -r "$FONTCONFIG_INSTALL/etc/fonts/fonts.conf" "$LILYPOND_DIR/etc/fonts"
sed_i "\\|$FONTCONFIG_INSTALL|d" "$LILYPOND_DIR/etc/fonts/fonts.conf"

# Copy needed files for Guile. Source files in share/ should go before ccache
# to avoid warnings.
for d in share lib; do
    cp -r "$GUILE_INSTALL/$d/guile" "$LILYPOND_DIR/$d/guile"
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
cp -r "$ROOT/relocate" "$LILYPOND_DIR/etc"

# Create archive.
(
    cd "$PACKAGE_DIR"
    zip --recurse-paths --quiet "$ROOT/$LILYPOND_MINGW_ZIP" $TAR_ARGS lilypond
)
