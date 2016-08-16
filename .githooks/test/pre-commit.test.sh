#!/bin/bash

# test the pre-commit hooks
TEST_NAME=TEST_$RANDOM
TEST_CASE="unknown_test_case"
TEST_FILE=$TEST_NAME.txt
TEST_BRANCH=$TEST_NAME

test_echo() {
    echo "[HOOK_TEST]: $*"
}

quote() {
    sed 's/^\(.*\)$/"\1"/g';
}

trim_hash() {
   cut -c 1-8
}

# make the hook scripts extra verbose, so we can debug
export HOOK_VERBOSE=1

test_echo "Test Run: $TEST_NAME"

# save the original head, so we can force our way back to it at the end of the test
ORIGINAL_BRANCH=$(git rev-parse -q --verify --abbrev-ref HEAD)
ORIGINAL_HEAD=$(git rev-parse -q --verify HEAD | trim_hash)
ORIGINAL_STASH=$(git rev-parse -q --verify refs/stash | trim_hash)

prepare_test() {
    test_echo "preparing test: $TEST_CASE"
}

restore_state() {
    MY_CURRENT_HEAD=$(git rev-parse -q --verify HEAD | trim_hash)
    if [ "$MY_CURRENT_HEAD" != "$ORIGINAL_HEAD" ]
    then
        test_echo "restoring state"
        git reset -q --hard $ORIGINAL_HEAD
    fi

    # restore the stash
    CURRENT_STASH=$(git rev-parse -q --verify refs/stash | trim_hash)
    while [ "$CURRENT_STASH" != "$ORIGINAL_STASH" ]
    do
        test_echo "Dropping stash $CURRENT_STASH"
        git stash drop -q
        CURRENT_STASH=$(git rev-parse -q --verify refs/stash | trim_hash)
    done

    rm -rf ./${TEST_NAME}*
}

success() {
    test_echo "Test passed: '$TEST_CASE'"
    restore_state
}

fail() {
    test_echo "Test failed: '$TEST_CASE' with error: '$*'"
    git checkout -f $ORIGINAL_BRANCH
    exit 1
}

update_file() {
    echo "test $*" >> $TEST_FILE
    git add $TEST_FILE >/dev/null 2>&1
}

check_commit_succeeded() {
    # make sure the commit succeeded
    RESULT=$1
    if [ $RESULT -ne 0 ] 
    then
        fail "The commit failed, see above."
    fi
}

check_commit_failed() {
    # make sure the commit failed
    RESULT=$1
    if [ $RESULT -ne 1 ] 
    then
        fail "The commit succeeded, but should have failed, see above."
    fi
}

check_no_changes() {
    # make sure that there are no in-work changes
    CHANGES=$(git diff HEAD)
    if [ "$CHANGES" ];
    then
        test_echo "Found changes: $CHANGES"
        fail "The commit succeeded, but there are changes, which isn't right."
    fi
}

check_unstaged_stash() {
    PARENT_COMMIT=$(echo $1 | trim_hash)
    # make sure that there is no stash left over from the original commit
    # check the stash -- these names have to match what is in the 000-stash.sh script
    FOUND_UNSTAGED_STASH=$(git stash list | grep " unstaged-stash-for-child-of-$PARENT_COMMIT")
    if [ -z "$FOUND_UNSTAGED_STASH" ]
    then
        test_echo "Looking for unstaged stash for '$PARENT_COMMIT'"
        fail "There should be an unstaged stash."
    fi
}

check_staged_stash() {
    PARENT_COMMIT=$(echo $1 | trim_hash)
    FOUND_STAGED_STASH=$(git stash list | grep " staged-stash-for-child-of-$PARENT_COMMIT")
    git stash list | cat
    if [ -z "$FOUND_STAGED_STASH" ]
    then
        test_echo "Looking for staged stash for '$PARENT_COMMIT'"
        fail "There should be a staged stash."
    fi
}

check_no_unstaged_stash() {
    # make sure that there is no unstaged stash left over from the original commit
    # check the stash -- these names have to match what is in the 000-stash.sh script
    FOUND_UNSTAGED_STASH=$(git stash list | grep " unstaged-stash-for-child-of-$ORIGINAL_HEAD")
    if [ "$FOUND_UNSTAGED_STASH" ]
    then
        fail "There should be no unstaged stash."
    fi
}

check_no_staged_stash() {
    FOUND_STAGED_STASH=$(git stash list | grep " staged-stash-for-child-of-$ORIGINAL_HEAD")
    if [ "$FOUND_STAGED_STASH" ]
    then
        fail "There should be no staged stash."
    fi
}

check_original_stash() {
    CURRENT_STASH=$(git rev-parse -q --verify refs/stash | trim_hash)
    # make sure the stash matches the original stash before we all started
    if [ "$CURRENT_STASH" != "$ORIGINAL_STASH" ]
    then
        test_echo "Current stash ($CURRENT_STASH) does not match original stash ($ORIGINAL_STASH)"
        fail "The commit hooks left some stuff on the stash."
    fi
}

check_file_created_and_added() {
    test_echo "Creating test file..."
    update_file "add"
    git commit -m "$TEST_NAME: $TEST_FILE"
    
    check_commit_succeeded $?
    check_no_changes
    check_no_unstaged_stash
    check_no_staged_stash
    check_original_stash
}

check_file_contents() {
    CURRENT_FILE_CONTENTS=$1
    EXPECTED_FILE_CONTENTS=$2
    if [ "$CURRENT_FILE_CONTENTS" != "$EXPECTED_FILE_CONTENTS" ]
    then
        test_echo "Found: "
        test_echo "$CURRENT_FILE_CONTENTS"
        test_echo "Expected: "
        test_echo "$EXPECTED_FILE_CONTENTS"
    
        fail "The staged changes should have persisted"
    fi
}

# remove any existing .hookstate file
rm -f .githooks/.hookstate

# create a new test branch
git checkout -b $TEST_BRANCH

################################
# test empty commit
################################
prepare_test "Empty Commit"

# uncomment this to fail the first test
#export FAIL_HOOKS=1

# uncomment this to fail the second test
#export TEST_HOOK_MODIFY_WORKTREE=1

git commit --allow-empty -m "test empty commit" 

check_commit_succeeded $?
check_no_changes

restore_state

################################
# test simple change with new file, no working changes or hook errors
################################
TEST_CASE="Simple change with new file, no working changes or hook errors"
prepare_test 

# uncomment this to fail the first test
#export FAIL_HOOKS=1
check_file_created_and_added

success


################################
# test simple change with existing file, no working changes or hook errors
################################
TEST_CASE="Simple change, no working changes or hook errors"
prepare_test 

# uncomment this to fail the first test
#export FAIL_HOOKS=1

# first create the file (same as above test, should pass fine)
check_file_created_and_added

# update the existing file
update_file "works"
git commit -m "$TEST_NAME: $TEST_FILE"

check_commit_succeeded $?
check_no_changes
check_no_unstaged_stash
check_no_staged_stash

success

################################
# test simple change with existing file, no working changes with hook errors
################################
TEST_CASE="Simple change with existing file, no working changes with hook errors"
prepare_test

check_file_created_and_added

# get the current head so we can confirm the stash
CURRENT_HEAD=$(git rev-parse -q --verify HEAD)

# force the test hook to fail
export FAIL_HOOKS=1

update_file "broke"
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_failed $?

# make sure the staged changes are correct
CURRENT_FILE_CONTENTS=$(cat $TEST_FILE | quote)
EXPECTED_FILE_CONTENTS=$(echo "test add
test broke" | quote)

check_file_contents "$CURRENT_FILE_CONTENTS" "$EXPECTED_FILE_CONTENTS"

check_no_unstaged_stash
check_staged_stash $CURRENT_HEAD

# check that the .hookstate file exists and has the right content
if [ ! -e .githooks/.hookstate ]
then
    fail "The .githooks/.hookstate file does not exist."
fi

# now correct the error by updating the file
update_file "fix"

# force the test hook to pass
unset FAIL_HOOKS

test_echo "Retrying commit..."

# try the commit again
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_succeeded $?

check_no_changes
check_original_stash

success 

################################
# test simple change with new file, no working changes with hook errors
################################
TEST_CASE="Simple change with new file, no working changes with hook errors"
prepare_test

# get the current head so we can confirm the stash
CURRENT_HEAD=$(git rev-parse -q --verify HEAD)

# force the test hook to fail
export FAIL_HOOKS=1

update_file "add broke"

git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_failed $?

# make sure the staged changes are correct
CURRENT_FILE_CONTENTS=$(cat $TEST_FILE | quote)
EXPECTED_FILE_CONTENTS=$(echo "test add broke" | quote)

check_file_contents "$CURRENT_FILE_CONTENTS" "$EXPECTED_FILE_CONTENTS"

check_no_unstaged_stash
check_staged_stash $CURRENT_HEAD

update_file "fix"

# force the test hook to pass
unset FAIL_HOOKS

# try the commit again
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_succeeded $?
check_no_changes
check_original_stash

success 

################################
# test simple change, working changes, no hook errors
################################
TEST_CASE="Simple change, working changes, no hook errors"
prepare_test 

# first create the file (same as above test, should pass fine)
check_file_created_and_added

# update the existing file
update_file "works"

# add in-work changes
echo "in-work" >> $TEST_FILE

git commit -m "$TEST_NAME: $TEST_FILE"

check_commit_succeeded $?
check_no_unstaged_stash
check_no_staged_stash

# confirm the working changes have been restored
CURRENT_FILE_CONTENTS=$(cat $TEST_FILE | quote)
EXPECTED_FILE_CONTENTS=$(echo "test add
test works
in-work" | quote)

check_file_contents "$CURRENT_FILE_CONTENTS" "$EXPECTED_FILE_CONTENTS"

success

################################
# test simple change, working changes and hook errors
################################
TEST_CASE="Simple change, working changes and hook errors"
prepare_test 

# first create the file (same as above test, should pass fine)
check_file_created_and_added

# update the existing file
update_file "broke"

# get the current head so we can confirm the stash
CURRENT_HEAD=$(git rev-parse -q --verify HEAD)

# force the test hook to fail
export FAIL_HOOKS=1

# add in-work changes -- make them prepend the file, so that there is not a conflict with the "fix" below
sed -i '1i in-work' $TEST_FILE

git commit -m "$TEST_NAME: $TEST_FILE"

check_commit_failed $?

# check that the .hookstate file exists and has the right content
if [ ! -e .githooks/.hookstate ]
then
    fail "The .githooks/.hookstate file does not exist."
fi

# now correct the error by updating the file
update_file "fix"

# force the test hook to pass
unset FAIL_HOOKS

test_echo "Retrying commit..."

# try the commit again
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_succeeded $?

# confirm the working changes have been restored
CURRENT_FILE_CONTENTS=$(cat $TEST_FILE | quote)
EXPECTED_FILE_CONTENTS=$(echo "in-work
test add
test broke
test fix" | quote)

check_file_contents "$CURRENT_FILE_CONTENTS" "$EXPECTED_FILE_CONTENTS"

check_original_stash

git diff HEAD | cat

success

################################
# test simple change, multiple working changes, and hook errors
################################
TEST_CASE="Simple change, multiple working changes and hook errors"
prepare_test 

# first create the file (same as above test, should pass fine)
check_file_created_and_added

# update the existing file
update_file "broke"

# get the current head so we can confirm the stash
CURRENT_HEAD=$(git rev-parse -q --verify HEAD)

# force the test hook to fail
export FAIL_HOOKS=1

# add in-work changes -- make them prepend the file, so that there is not a conflict with the "fix" below
sed -i '1i in-work 1' $TEST_FILE

git commit -m "$TEST_NAME: $TEST_FILE"

check_commit_failed $?

# check that the .hookstate file exists and has the right content
if [ ! -e .githooks/.hookstate ]
then
    fail "The .githooks/.hookstate file does not exist."
fi

# now correct the error by updating the file
update_file "fix"

# add more in-work changes, but substitute the line so we don't get a conflict
sed -i 's/test add/test add in-work 2/' $TEST_FILE

# force the test hook to pass
unset FAIL_HOOKS

test_echo "Retrying commit the first time..."

# try the commit again, it should fail because of multiple working-changes
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_failed $?

# force the commit to proceed in spite of multiple working-changes
export HOOK_FORCE_UNSTAGED_STASH=1

test_echo "Retrying commit the second time..."

# try the commit again, it should fail because of multiple working-changes
git commit -m "$TEST_NAME: $TEST_FILE"
check_commit_succeeded $?

# confirm the working changes have been restored
CURRENT_FILE_CONTENTS=$(cat $TEST_FILE | quote)
EXPECTED_FILE_CONTENTS=$(echo "test add in-work 2
test broke
test fix" | quote)

check_file_contents "$CURRENT_FILE_CONTENTS" "$EXPECTED_FILE_CONTENTS"

check_unstaged_stash $CURRENT_HEAD
check_no_staged_stash $CURRENT_HEAD

success


################################
# test simple change, working changes, untracked files, no hook errors
################################

################################
# test simple change, working changes, untracked files and hook errors
################################


################################
# test simple change with stash conflicts
################################

# restore the original state
restore_state
# FIXME: how to restore original stash?

git checkout -q -f $ORIGINAL_BRANCH
git branch -D -q $TEST_BRANCH

test_echo "ALL TESTS PASSED SUCCESSFULLY"
