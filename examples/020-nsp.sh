#!/bin/bash

# A pre-commit hook to run the node security platform (https://nodesecurity.io/opensource)
# if the package.json changes

source .githooks/hook_utils.sh

NSP=./node_modules/.bin/nsp

# Get committed package.json / npm-shrinkwrap.json
FILES="$(modified_files_to_commit | grep '^\(package.json\|npm-shrinkwrap.json\)$')"

if [ -z "$FILES" ]
then
    hook_echo "No changes found to package.json or npm-shrinkwrap.json, skipping NSP checker."
    exit 0
else

    NSP_OUTPUT=$($NSP check)
    NSP_RESULT=$?
   
    if [ "$NSP_OUTPUT" ]
    then
        echo "$NSP_OUTPUT" | hook_pipe_error
    fi

    if [ $NSP_RESULT -ne 0 ]
    then
        hook_error "You added packages that fail the NSP checker."
        if [ "$HOOK_OVERRIDE_NSP" = "1" ]
        then
            hook_echo "By setting HOOK_OVERRIDE_NSP=1, you have overridden this test, and the hook will proceed."
            exit 0
        else
            hook_error "Fix this, or set HOOK_OVERRIDE_NSP=1 to allow the commit to proceed anyway, and try again."
            exit 1
        fi
    fi
fi
