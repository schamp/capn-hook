#!/bin/sh

source .githooks/hook_utils.sh

hook_echo "Running hook on files: $(files_to_commit)"

#git status
#hook_echo cached_diff:
#git diff --cached | cat
#hook_echo uncached_diff:
#git diff | cat
#hook_echo top of stash:
#git stash show -p | cat

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

