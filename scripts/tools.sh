. "$(dirname $0)/common.sh"

TOOLS_BIN="$TOOLS/bin"

if [ ! -d "$TOOLS" ]; then
    if ! type gperf >/dev/null 2>&1; then
        echo "Please install gperf!" >&2
        exit 1
    fi
    TOOLS_GPERF=gperf
    return
fi

TOOLS_GPERF="$TOOLS_BIN/gperf"

TOOLS_PYTHONPATH=""
for dir in $(find "$TOOLS/" -name "site-packages"); do
    if [ -n "$TOOLS_PYTHONPATH" ]; then
        TOOLS_PYTHONPATH=":$TOOLS_PYTHONPATH"
    fi
    TOOLS_PYTHONPATH="$dir$TOOLS_PYTHONPATH"
done

# Set environment variables such that the installed Python packages can be used.
# FIXME: Find a portable way to write this as a function.
if [ -z "$PATH" ]; then
    export PATH="$TOOLS_BIN"
else
    export PATH="$TOOLS_BIN:$PATH"
fi
if [ -z "$PYTHONPATH" ]; then
    export PYTHONPATH="$TOOLS_PYTHONPATH"
else
    export PYTHONPATH="$TOOLS_PYTHONPATH:$PYTHONPATH"
fi
