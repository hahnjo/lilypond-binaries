#!/bin/sh

set -e

. "$(dirname $0)/native_deps.sh"

PACKAGE_DIR="$ROOT/package"
LILYPOND_DIR="$PACKAGE_DIR/lilypond"
LILYPOND_INSTALL="$ROOT/lilypond/install"

os="$(uname | tr '[A-Z]' '[a-z]')"
arch="$(uname -m | tr '[A-Z]' '[a-z]')"
LILYPOND_TAR="lilypond-$os-$arch.tar.gz"

echo "Creating '$LILYPOND_TAR'..."

rm -rf "$PACKAGE_DIR"
mkdir -p "$LILYPOND_DIR"
for dir in bin etc lib share; do
    mkdir "$LILYPOND_DIR/$dir"
done

# Copy all of LilyPond.
cp -r "$LILYPOND_INSTALL"/* "$LILYPOND_DIR"
strip "$LILYPOND_DIR/bin/lilypond"

# Copy configuration files for Fontconfig.
mkdir -p "$LILYPOND_DIR/etc/fonts"
cp -r "$FONTCONFIG_INSTALL/etc/fonts/fonts.conf" "$LILYPOND_DIR/etc/fonts"
$SED_I "\\|$FONTCONFIG_INSTALL|d" "$LILYPOND_DIR/etc/fonts/fonts.conf"

# Copy needed files for Guile.
cp "$GUILE_INSTALL/lib"/libguile-srfi-srfi-*.so "$LILYPOND_DIR/lib"
strip "$LILYPOND_DIR/lib"/libguile-srfi-srfi-*.so
cp -r "$GUILE_INSTALL/share/guile" "$LILYPOND_DIR/share"

# Copy Ghostscript binary.
cp "$GHOSTSCRIPT_INSTALL/bin/gs" "$LILYPOND_DIR/bin"
strip "$LILYPOND_DIR/bin/gs"

# Copy files for relocation.
cp -r "$ROOT/relocate" "$LILYPOND_DIR/etc"

# Create archive.
(
    cd "$PACKAGE_DIR"
    tar czof "$ROOT/$LILYPOND_TAR" lilypond
)
