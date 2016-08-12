#!/bin/sh

source .githooks/hook_utils.sh

hook_echo "Running hook on files: $(files_to_commit)"

if [ $TEST_HOOK_MODIFY_WORKTREE ]
then
    echo "foobar" >> .gitignore
fi

if [ $FAIL_HOOKS ]
then
    hook_error "Test hook failing"
    exit 1
else 
    hook_echo "Test hook passing"
    exit 0
fi

