if [ -n "$COMMON_INCLUDED" ]; then
    return
fi
COMMON_INCLUDED="1"

ROOT="$(pwd)"
DOWNLOADS="$ROOT/downloads"
TOOLS="$ROOT/tools"
TOOLS_BIN="$TOOLS/bin"


# Detect environment.
uname="$(uname)"
if [ "$uname" = "Linux" ]; then
    MAKE=make
    sed_i()
    (
        sed -i "$@"
    )
elif [ "$uname" = "FreeBSD" ]; then
    if ! type gmake >/dev/null 2>&1; then
        echo "Please install GNU make!" >&2
        exit 1
    fi
    MAKE=gmake
    sed_i()
    (
        sed -i '' "$@"
    )
fi

if [ -z "$PROCS" ]; then
    if type nproc >/dev/null 2>&1; then
        PROCS=$(nproc)
    elif [ "$uname" = "FreeBSD" ] || [ "$uname" = "Darwin" ]; then
        PROCS=$(sysctl -n hw.ncpu)
    fi
fi


# Auxilary functions
download()
(
    local url="$1"
    local file="$2"
    local download_file="$DOWNLOADS/$file"

    if [ -f "$download_file" ]; then
        echo "'$file' already exists!"
        return
    fi

    echo "Downloading '$url'..."
    mkdir -p "$DOWNLOADS"
    curl --silent --location "$url" --output "$download_file"
)

# When using function together with a subshell, be sure to write
#     ( ) &
#     wait $! || print_failed_and_exit
# instead of just
#     ( ) || print_failed_and_exit
# Otherwise set -e is not propagated to the subshell! See
# https://unix.stackexchange.com/a/254675 for an explanation.
print_failed_and_exit()
(
    echo "FAILED: See $1 for more information"
    exit 1
)

extract()
(
    local file="$1"
    local download_file="$DOWNLOADS/$file"
    local src_dir="$2"

    if [ -d "$src_dir" ]; then
        echo "'$file' already extracted!"
        return
    fi

    echo "Extracting '$file'..."
    mkdir -p "$src_dir"
    tar -x -f "$download_file" -C "$src_dir" --strip-components 1
)

