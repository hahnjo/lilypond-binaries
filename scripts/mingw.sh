. "$(dirname $0)/common.sh"

MINGW_ROOT="$ROOT/mingw"
MINGW_TOOLCHAIN="$MINGW_ROOT/toolchain"
MINGW_TOOLCHAIN_INSTALL="$MINGW_TOOLCHAIN/install"

MINGW_TARGET="x86_64-w64-mingw32"

# Before building, put installation directory into PATH.
# (${parameter:+word} -- if parameter is set and is not null,
#  then substitute the value of word).
PATH=$MINGW_TOOLCHAIN_INSTALL/bin${PATH:+:$PATH}
