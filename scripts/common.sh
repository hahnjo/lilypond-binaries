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
    SED_I="sed -i"
elif [ "$uname" = "FreeBSD" ]; then
    if ! type gmake >/dev/null 2>&1; then
        echo "Please install GNU make!" >&2
        exit 1
    fi
    MAKE=gmake
    SED_I="sed -i ''"
fi

if [ -z "$PROCS" ]; then
    if type nproc >/dev/null 2>&1; then
        PROCS=$(nproc)
    elif [ "$(uname)" = "FreeBSD" ]; then
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

