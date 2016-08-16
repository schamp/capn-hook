#!/bin/sh
# script to run tests on what is to be committed
# based on http://stackoverflow.com/a/20480591/1606867

# split into two and modified. 
# any hooks in this folder will be run with a working directory exactly in the state as is to be committed
# any changes made to the working copy will be preserved so the user may elect to add them and try the commit again
# (e.g., have the standards-checker automatically reformat the source)

# FIXME: put the above into a readme

source .githooks/hook_utils.sh

# all hooks run in the context of the root of the repository
# FIXME: put into hook_utils.sh?
hook_state_file=.githooks/.hookstate

# if it's an empty commit, skip the hooks
FILES=$(files_to_commit)
if [ -z "$FILES" ]
then
    hook_echo "No files staged for commit, skipping stash for empty commit."
    exit 0
fi

# remember old stash
old_stash=$(git rev-parse -q --verify refs/stash)

# remember the original parent to track retries
orig_parent_commit=$(git rev-parse -q --verify HEAD | cut -c 1-8)

# to help track the stashes
message="for-child-of-$orig_parent_commit"

hook_verbose "Looking for hook state file '$hook_state_file'..."
# check to see if we are retrying a commit that aborted due to hook failure 
if [ -e $hook_state_file ]
then
#    hook_echo "Found hook state file."
    source $hook_state_file

#    echo orig_parent_commit: $orig_parent_commit
#    echo parent_commit: $parent_commit

    if [ "$parent_commit" = "$orig_parent_commit" ];
    then
        hook_echo "Continuing prior commit..."

        # here we need to check the prior stashes from the most recent failed attempt
        # the staged-stash contains what was staged for the failed commit attempt
        # we can just drop that, because it failed and presumeably the corrected stuff 
        # is now staged for the current retry commit
        STASH_MESSAGE=staged-stash-$message
        hook_verbose "Checking for existing staged-stash from prior commit '$STASH_MESSAGE'..."
        PRIOR_STAGED_STASH=$(git stash list | grep " $STASH_MESSAGE" | cut -c 1-9)
        if [ "$PRIOR_STAGED_STASH" ]
        then
            hook_verbose "Dropping prior staged stash $PRIOR_STAGED_STASH"
            git stash drop -q $PRIOR_STAGED_STASH
        else
            hook_error "Prior staged-stash not found!?"
        fi
       
        # there may be an untracked-changes stash
        # but we want to leave it in place so that it can be applied after the successful commit
        # right?
        UNSTAGED_MESSAGE=unstaged-stash-$message
        PRIOR_UNSTAGED_STASH=$(git stash list | grep " $UNSTAGED_MESSAGE")
        if [ "$PRIOR_UNSTAGED_STASH" ]
        then
            hook_verbose "Found prior unstaged stash(es):"
            hook_verbose "$PRIOR_UNSTAGED_STASH"
        else
            hook_verbose "Found no prior unstaged stash."
        fi

        # if there is a prior unstaged stash *and* current unstaged changes, warn the user
        # because the two unstaged stashes cannot be applied on top of each other automatically
        MORE_UNSTAGED_CHANGES=$(git diff --name-only)
        if [ "$PRIOR_UNSTAGED_STASH" ] && [ "$MORE_UNSTAGED_CHANGES" ]
        then
            hook_error "It appears that you have several layers of unstaged changes:"
            hook_error "On the stash:"
            hook_error "$(echo "$PRIOR_UNSTAGED_STASH" | indent)"
            hook_error "In the working tree:"
            hook_error "$(echo "$MORE_UNSTAGED_CHANGES" | indent)"
            hook_error "These cannot automatically be merged after the hooks run."
            if [ "$HOOK_FORCE_UNSTAGED_STASH" = "1" ]
            then
                hook_echo "Because you set HOOK_FORCE_UNSTAGED_STASH=1, the hook will continue."
                hook_echo "You will receive another warning after all the hooks run successfully,"
                hook_echo "And the commit will proceed."
                hook_echo "After the commit has concluded, you will receive another warning,"
                hook_echo "and it will be up to you to clean things up and make sure you don't lose anything."
            else
                hook_echo "Please stop and clean up these unstaged changes yourself,"
                hook_echo "combine them with the prior unstaged stash, or revert them."
                hook_echo "To force the commit to proceed even with multiple layers of unstaged changes,"
                hook_echo "set HOOK_FORCE_UNSTAGED_STASH=1 in the environment, and try again."
                exit 1
            fi
        fi
    else
        hook_error "Found stale hook state in $hook_state_file, aborting pre-commit hooks."
        hook_error "If you want to try anyway, delete $hook_state_file and try again."
        exit 1
    fi
else
    hook_verbose "Hook state file not found."
fi

# stash only the unsaved changes.  Regular git stash includes staged changes, but we don't want that.
# Here's the workaround, from: http://stackoverflow.com/a/29863853/123674
# tell the stash-cleanup.sh hook, if it's configured, not to run
export HOOK_SKIP_STASH_CLEANUP_CHECK=1
git commit -q --no-verify -m "~~~ saved index ~~~"
git stash save -q "unstaged-stash-$message"
unstaged_stash=$(git rev-parse -q --verify refs/stash)
git reset -q --soft HEAD~1
unset HOOK_SKIP_STASH_CLEANUP_CHECK

# Now the staged changes are back in the index,
# and the unstaged ones are in the stash.
# Let's stash the staged changes, so we can get the untracked files separately.
hook_echo "Stashing saved changes..."
git stash save -q "staged-stash-$message"
staged_stash=$(git rev-parse -q --verify refs/stash)
if [ "$changes_stash" = "$staged_stash" ]
then
    hook_echo "pre-commit script: no staged changes to test"
    # re-apply changes_stash 
    git reset --hard -q && git stash pop --index -q
    sleep 1 # XXX hack, editor may erase message TODO: why? can we get rid of this?
    exit 0
fi

# Add all untracked files and stash those as well
# We don't want to use -u due to
# http://blog.icefusion.co.uk/git-stash-can-delete-ignored-files-git-stash-u/
hook_echo "Stashing untracked files..."
git add .
git stash save -q "untracked-stash-$message"
untracked_stash=$(git rev-parse -q --verify refs/stash)

# re-apply the staged changes
hook_echo "Re-applying staged changes..."
if [ "$staged_stash" = "$untracked_stash" ]
then
    # there are no untracked_stash changes, so re-apply the top, which should be the staged-stash
    git reset --hard -q && git stash apply --index -q stash@{0}
else
    # there are untracked_stash changes, so re-apply the staged-stash out from under the untracked stash
    git reset --hard -q && git stash apply --index -q stash@{1}
fi

# now we run tests, hand it over to the other scripts
# if a script returns non-zero, the hooks will be stopped
# we want some kind of script or alias to restore things

# export meaningful state so the other scripts (i.e., 999-unstash.sh) can find it
hook_echo "Saving hook state for cleanup script..."

echo "" > $hook_state_file
echo "message=$message" >> $hook_state_file
echo "unstaged_stash=$unstaged_stash" >> $hook_state_file
echo "staged_stash=$staged_stash" >> $hook_state_file
echo "untracked_stash=$untracked_stash" >> $hook_state_file
echo "parent_commit=$orig_parent_commit" >> $hook_state_file

# exit with good status to find first script
exit 0
