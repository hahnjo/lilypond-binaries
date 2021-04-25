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

if [ "$uname" = "Linux" ]; then
    TAR_ARGS="--owner=0 --group=0"
elif [ "$uname" = "FreeBSD" ]; then
    TAR_ARGS="--uid=0 --gid=0"
fi

echo "Creating '$LILYPOND_TAR'..."

rm -rf "$PACKAGE_DIR"
rm -f "$LILYPOND_TAR"
rm -f "$LILYPOND_FULL_TAR"

mkdir -p "$LILYPOND_DIR"
for dir in bin etc lib share; do
    mkdir "$LILYPOND_DIR/$dir"
done

# Copy all of LilyPond.
cp -RL "$LILYPOND_INSTALL"/* "$LILYPOND_DIR"
strip "$LILYPOND_DIR/bin/lilypond"

# Adapt shebang of Python scripts.
for s in $PYTHON_SCRIPTS; do
    sed_i "1 s|.*|#!/usr/bin/env python3|" "$LILYPOND_DIR/bin/$s"
done
# Adapt shebang of Guile scripts.
for s in $GUILE_SCRIPTS; do
    sed_i "1 s|.*|#!/usr/bin/env guile --no-auto-compile|" "$LILYPOND_DIR/bin/$s"
done

# Copy configuration files for Fontconfig.
cp -RL "$FONTCONFIG_INSTALL/etc/fonts" "$LILYPOND_DIR/etc/"
sed_i "\\|$FONTCONFIG_INSTALL|d" "$LILYPOND_DIR/etc/fonts/fonts.conf"

# Copy needed files for Guile. Source files in share/ should go before ccache
# to avoid warnings.
for d in share lib; do
    cp -RL "$GUILE_INSTALL/$d/guile" "$LILYPOND_DIR/$d/guile"
done
# Delete guile-readline extension.
rm -rf "$LILYPOND_DIR/lib/guile/$GUILE_VERSION_MAJOR/extensions"

# Copy Ghostscript binary.
cp "$GHOSTSCRIPT_INSTALL/bin/gs" "$LILYPOND_DIR/bin"
strip "$LILYPOND_DIR/bin/gs"

# Copy files for relocation.
cp -RL "$ROOT/relocate" "$LILYPOND_DIR/etc"

# Create archive.
(
    cd "$PACKAGE_DIR"
    # Package lib/ last which contains the ccache for Guile.
    contents="$(ls -d lilypond/* | grep -v lilypond/lib) lilypond/lib"
    tar czf "$ROOT/$LILYPOND_TAR" $TAR_ARGS $contents
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
cp -RL "$PYTHON_INSTALL/lib/$python" "$LILYPOND_DIR/lib"
# ... but delete a number of directories we don't need:
(
    cd "$LILYPOND_DIR/lib/$python"
    rm -rf $(find . -type d -name "test")
    # This directory contains the libpython*.a library.
    rm -rf "config-$PYTHON_VERSION_MAJOR"*
    # "Distributing Python Modules"
    rm -rf "distutils"
    # "Integrated Development and Learning Environment"
    rm -rf "idlelib"
    # 2to3
    rm -rf "lib2to3"
    # The build system installs pip and setuptools.
    rm -rf "site-packages"
)
# Strip dynamically linked and loaded libraries.
strip "$LILYPOND_DIR/lib/$python/lib-dynload"/*.so

# Move Python scripts, instead create wrappers.
for s in $PYTHON_SCRIPTS; do
    mv "$LILYPOND_DIR/bin/$s" "$LILYPOND_DIR/scripts"
    wrapper="$LILYPOND_DIR/bin/$s"
    cat > "$wrapper" <<EOF
#!/bin/sh

root="\$(dirname \$0)/.."
exec "\$root/scripts/$python" "\$root/scripts/$s" "\$@"
EOF
    chmod a+x "$wrapper"
done
# Move Guile scripts, instead create wrappers.
for s in $GUILE_SCRIPTS; do
    mv "$LILYPOND_DIR/bin/$s" "$LILYPOND_DIR/scripts"
    wrapper="$LILYPOND_DIR/bin/$s"
    cat > "$wrapper" <<EOF
#!/bin/sh

root="\$(dirname \$0)/.."
export GUILE_AUTO_COMPILE=0
export GUILE_LOAD_PATH="\$root/share/guile/$GUILE_VERSION_MAJOR"
export GUILE_LOAD_COMPILED_PATH="\$root/lib/guile/$GUILE_VERSION_MAJOR/ccache"
exec "\$root/scripts/guile" "\$root/scripts/$s" "\$@"
EOF
    chmod a+x "$wrapper"
done

# Create archive.
(
    cd "$PACKAGE_DIR"
    # Package lib/ last which contains the ccache for Guile.
    contents="$(ls -d lilypond/* | grep -v lilypond/lib) lilypond/lib"
    tar czf "$ROOT/$LILYPOND_FULL_TAR" $TAR_ARGS $contents
)
