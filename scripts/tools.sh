if [ -n "$TOOLS_INCLUDED" ]; then
    return
fi
TOOLS_INCLUDED="1"

. "$(dirname $0)/common.sh"

if [ ! -d "$TOOLS_BIN" ]; then
    return
fi

# Set PATH such that the installed tools can be used.
# (${parameter:+word} -- if parameter is set and is not null,
#  then substitute the value of word). 
PATH=$TOOLS_BIN${PATH:+:$PATH}
