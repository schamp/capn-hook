#!/bin/sh

HOOK_FILE=`basename $0`

hook_echo () {
    echo $* | hook_pipe
}

hook_pipe() {
    sed "s/^/\[$HOOK_FILE\]: /g"
}

hook_verbose() {
    if [ "$HOOK_VERBOSE" = "1" ]
    then
        hook_echo $*
    fi
}

hook_error() {
    echo $* | sed "s/^/\[$HOOK_FILE\]: ERROR: /g"
}

hook_debug() {
    if [ $DEBUG ]; then
        hook_echo $*
    fi
}

files_to_commit() {
    FILES=$(git diff --cached --name-only)
    echo "$FILES"
}

indent() {
    sed "s/^/  /g"; 
}

