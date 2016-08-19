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

hook_pipe_error() {
    sed "s/^/\[$HOOK_FILE\]: ERROR: /g"
}

hook_debug() {
    if [ $DEBUG ]; then
        hook_echo $*
    fi
}

# get list of new or modified, but not deleted, files belonging to this commit
modified_files_to_commit() {
    FILES=$(git diff --cached --name-status | grep -v '^D' | cut -f 2)
    echo "$FILES"
}

# get list of all files belonging to this commit
files_to_commit() {
    FILES=$(git diff --cached --name-only)
    echo "$FILES"
}

indent() {
    sed "s/^/  /g"; 
}

