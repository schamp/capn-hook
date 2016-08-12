#!/bin/sh

source .githooks/hook_utils.sh

# Check to see if anything remains on the stash from the pre-commit hooks 
# and prompt the user so they can address it
hook_echo "Checking for old stashes to cleanup..."

UNTRACKED_STASHES=$(git stash list | grep " untracked-stash")
UNSTAGED_STASHES=$(git stash list | grep " unstaged-stash")
STAGED_STASHES=$(git stash list | grep " staged-stash")

# TODO: make more specific error messages / instructions for the different kinds of stashes
REMAINING_STASHES="$STAGED_STASHES $UNSTAGED_STASHES $UNTRACKED_STASHES"
if [ "$STAGED_STASHES" ] || [ "$UNSTAGED_STASHES" ] || [ "$UNTRACKED_STASHES" ]
then
    hook_echo "*************************<WARNING>****************************"
    hook_echo "It seems like there are old, stale stashes of unstaged changes:"
    hook_echo "$(echo "$REMAINING_STASHES" | indent)"
    hook_echo "Please clean them up if you are through with them"
    hook_echo "*************************</WARNING>***************************"
fi
