#!/bin/sh

set -e

# Cross-compile dependencies for LilyPond needed at runtime.

. "$(dirname $0)/mingw.sh"

# Include native_deps.sh to get the install location of native Guile.
. "$(dirname $0)/native_deps.sh"

NATIVE_GUILE_INSTALL="$GUILE_INSTALL"

# Now build the dependencies, but below MINGW_ROOT.
MINGW_CROSS="1"
DEPENDENCIES_ROOT="$MINGW_ROOT"

# Prepare argument for configure and meson.
CONFIGURE_HOST="--host=$MINGW_TARGET"

MESON_CROSS_FILE="$MINGW_ROOT/meson_cross.txt"
cat > "$MESON_CROSS_FILE" <<EOF
[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'

[binaries]
c = '$MINGW_TOOLCHAIN_INSTALL/bin/$MINGW_TARGET-gcc'
cpp = '$MINGW_TOOLCHAIN_INSTALL/bin/$MINGW_TARGET-g++'
windres = '$MINGW_TOOLCHAIN_INSTALL/bin/$MINGW_TARGET-windres'
pkgconfig = 'pkgconf'

[built-in options]
# -DG_INTL_STATIC_COMPILATION needed for glib2
c_args = ['-DG_INTL_STATIC_COMPILATION']
EOF
MESON_CROSS_ARG="--cross-file $MESON_CROSS_FILE"

. "$(dirname $0)/build_native_deps.sh"
