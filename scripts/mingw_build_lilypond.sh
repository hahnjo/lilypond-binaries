#!/bin/sh

set -e

. "$(dirname $0)/mingw.sh"

# Include native_deps.sh to get the install location of native Python.
. "$(dirname $0)/native_deps.sh"

NATIVE_PYTHON_INSTALL="$PYTHON_INSTALL"

# Now build LilyPond, but below MINGW_ROOT.
MINGW_CROSS="1"
DEPENDENCIES_ROOT="$MINGW_ROOT"

# Prepare argument for configure.
CONFIGURE_HOST="--host=$MINGW_TARGET"

. "$(dirname $0)/build_lilypond.sh"
