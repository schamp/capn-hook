#!/bin/sh

source .githooks/hook_utils.sh

FILES=$(files_to_commit)

if [ -z "$FILES" ]
then
    hook_echo "No files staged for commit, skipping stash for empty commit."
    exit 0
fi

# get saved state from 000-stash.sh hook
hook_state_file=.hookstate

hook_verbose "Reading hook state..."

if [ ! -f $hook_state_file ]; then
    hook_error "Hook state file $hook_state_file not found, cannot finish hook."
    exit 1
fi

source $hook_state_file

# don't check for unstaged_stash -- there might not be any, and the variable might be the empty string

if [ -z "$staged_stash" ]
then
    hook_error "\$staged_stash not found in hook state file $hook_state_file"
    exit 1
fi

if [ -z "$untracked_stash" ]
then
    hook_error "\$untracked_stash not found in hook state file $hook_state_file"
    exit 1
fi

# Restore changes
hook_echo "Restoring changes..."

# *must* do this before trying the restore, otherwise we'll get stash pop merge conflicts
hook_verbose "Cleaning up hook state file..."
rm $hook_state_file

# Restore untracked if any
if [ "$staged_stash" != "$untracked_stash" ]
then
    hook_echo "Restoring untracked changes..."
    git reset --hard -q && git stash pop --index -q
    git reset HEAD -- . -q
fi

# Restore staged changes
hook_echo "Restoring staged changes..."
git reset --hard -q && git stash pop --index -q

UNSTAGED_STASH=$(git stash list | head -n 1 | grep unstaged-stash)
# Restore unstaged changes that are on top of the stash
# there could be several, if there were several failed commits,
# each of which had different changes when they were attempted
# IF THERE IS MORE THAN ONE, the lower ones in the stack (the earlier ones) WILL FAIL TO APPLY.
# This is because the stash pop requires a clean working tree.  
# We try to prevent this by detecting unstaged changes during a commit retry and prompting the user.
while [ "$UNSTAGED_STASH" ]
do
    hook_echo "Restoring unstaged changes from $UNSTAGED_STASH..."
    git stash pop -q
    RESULT=$?
    if [ $RESULT -ne 0 ]
    then
        hook_error "Could not restore unstaged changes."
        hook_error "This usually happens when there are unstaged changes left on in several consecutive tries for the commit."

        if [ "$HOOK_FORCE_UNSTAGED_STASH" = "1" ]
        then
            hook_echo "Because you set HOOK_FORCE_UNSTAGED_STASH=1, the hook will continue."
            hook_echo "And the commit will proceed."
            hook_echo "It will be up to you to clean things up and make sure you don't lose anything."
            break
        else
            hook_echo "Please stop and clean up these unstaged changes yourself,"
            hook_echo "combine them with the prior unstaged stash, or revert them."
            hook_echo "To force the commit to proceed even with multiple layers of unstaged changes,"
            hook_echo "set HOOK_FORCE_UNSTAGED_STASH=1 in the environment, and try again."
            exit 1
        fi

    fi
	
    UNSTAGED_STASH=$(git stash list | head -n 1 | grep unstaged-stash)
done

# Exit with success
exit 0
