#!/bin/sh

set -e
umask 022

. "$(dirname $0)/native_deps.sh"

PACKAGE_DIR="$ROOT/package"
LILYPOND_DIR="$PACKAGE_DIR/lilypond"
LILYPOND_INSTALL="$ROOT/lilypond/install"

PYTHON_SCRIPTS="abc2ly convert-ly etf2ly lilymidi lilypond-book lilysong midi2ly musicxml2ly"
GUILE_SCRIPTS="lilypond-invoke-editor"

os="$(uname | tr '[A-Z]' '[a-z]')"
arch="$(uname -m | tr '[A-Z]' '[a-z]')"
LILYPOND_TAR="lilypond-$os-$arch.tar.gz"
LILYPOND_FULL_TAR="lilypond-$os-$arch-full.tar.gz"

echo "Creating '$LILYPOND_TAR'..."

rm -rf "$PACKAGE_DIR"
mkdir -p "$LILYPOND_DIR"
for dir in bin etc lib share; do
    mkdir "$LILYPOND_DIR/$dir"
done

# Copy all of LilyPond.
cp -r "$LILYPOND_INSTALL"/* "$LILYPOND_DIR"
strip "$LILYPOND_DIR/bin/lilypond"

# Adapt shebang of Python scripts.
for s in $PYTHON_SCRIPTS; do
    sed_i "1 s|.*|#!/usr/bin/env python2|" "$LILYPOND_DIR/bin/$s"
done
# Adapt shebang of Guile scripts.
for s in $GUILE_SCRIPTS; do
    sed_i "1 s|.*|#!/usr/bin/env guile|" "$LILYPOND_DIR/bin/$s"
done

# Copy configuration files for Fontconfig.
mkdir -p "$LILYPOND_DIR/etc/fonts"
cp -r "$FONTCONFIG_INSTALL/etc/fonts/fonts.conf" "$LILYPOND_DIR/etc/fonts"
sed_i "\\|$FONTCONFIG_INSTALL|d" "$LILYPOND_DIR/etc/fonts/fonts.conf"

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

echo "Creating '$LILYPOND_FULL_TAR'..."

mkdir -p "$LILYPOND_DIR/scripts"
# Also add Guile and Python executables for scripts.
cp "$GUILE_INSTALL/bin/guile" "$LILYPOND_DIR/scripts"
strip "$LILYPOND_DIR/scripts/guile"
python="python$PYTHON_VERSION_MAJOR"
cp "$PYTHON_INSTALL/bin/$python" "$LILYPOND_DIR/scripts"
strip "$LILYPOND_DIR/scripts/$python"

# Copy packages for Python ...
cp -r "$PYTHON_INSTALL/lib/$python" "$LILYPOND_DIR/lib"
# ... but delete tests.
rm -r "$LILYPOND_DIR/lib/$python/test"

# Move Python scripts, instead create wrappers.
for s in $PYTHON_SCRIPTS; do
    mv "$LILYPOND_DIR/bin/$s" "$LILYPOND_DIR/scripts"
    wrapper="$LILYPOND_DIR/bin/$s"
    cat > "$wrapper" <<EOF
#!/bin/sh

script="\$(basename \$0)"
root="\$(dirname \$0)/.."
exec "\$root/scripts/$python" "\$root/scripts/\$script" "\$@"
EOF
    chmod a+x "$wrapper"
done
# Move Guile scripts, instead create wrappers.
for s in $GUILE_SCRIPTS; do
    mv "$LILYPOND_DIR/bin/$s" "$LILYPOND_DIR/scripts"
    wrapper="$LILYPOND_DIR/bin/$s"
    cat > "$wrapper" <<EOF
#!/bin/sh

script="\$(basename \$0)"
root="\$(dirname \$0)/.."
export GUILE_LOAD_PATH="\$root/share/guile/$GUILE_VERSION_MAJOR"
export LD_LIBRARY_PATH="\$root/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$root/scripts/guile" "\$root/scripts/\$script" "\$@"
EOF
    chmod a+x "$wrapper"
done

# Create archive.
(
    cd "$PACKAGE_DIR"
    tar czof "$ROOT/$LILYPOND_FULL_TAR" lilypond
)
