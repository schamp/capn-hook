#!/bin/bash


# A pre-commit hook to run the standard-format program to auto-format
# the committed source files according to standard-js (http://standardjs.com).
# It first auto-formats everything that can be auto-corrected, then it runs
# standard after that to identify things that require manual intervention.
# If changes are made or manual changes are required, will abort the commit
# and allow the user an opportunity to add automatic changes and implement 
# manual ones before retrying the commit.
source .githooks/hook_utils.sh

# Get committed js or jsx files.
# We don't want to try and format files that have been deleted.
FILES="$(modified_files_to_commit | grep '\.jsx\?$')"
FORMATTER=./node_modules/.bin/standard-format
CHECKER=./node_modules/.bin/standard
ERROR=

if [ ! -x "$FORMATTER" ]
then
    hook_error "The standard formatter $FORMATTER does not appear to be installed.  Please run 'npm install --save-dev standard-format' to install it."
    ERROR=1
fi

if [ ! -x "$CHECKER" ]
then
    hook_error "The standard checker $CHECKER does not appear to be installed.  Please run 'npm install --save-dev standard' to install it."
    ERROR=1
fi

if [ "$ERROR" ]
then
    exit 1
fi

if [ -z "$FILES" ]
then
    hook_echo "No changes found to js files, skipping standards checker."
    exit 0
else
    hook_echo "Running standards checker on files: $FILES"

    # check config to see if we should force-format it
    FORMATTER_OUTPUT=$($FORMATTER -w $FILES)
    if [ "$FORMATTER_OUTPUT" ]
    then
        echo "$FORMATTER_OUTPUT" | hook_pipe_error
    fi

    # run the checker SECOND so that if there are violations the formatter can't fix,
    # only those are displayed to the user
    CHECKER_OUTPUT=$($CHECKER $FILES 2>/dev/null)

    FAILED_CHECKER=$?

    if [ "$CHECKER_OUTPUT" ]
    then
        echo "$CHECKER_OUTPUT" | hook_pipe_error
    fi

    # check to see if there are any unstaged changes, if so, we need to abort and add them
    CHANGED_FILES_TO_ADD=$(git diff --name-only)

    if [ "$CHANGED_FILES_TO_ADD" ] || [ $FAILED_CHECKER -ne 0 ]
    then
        if [ "$CHANGED_FILES_TO_ADD" ]; then
            hook_error "Some of your changes failed the standards checker."
            hook_error "They have been automatically formatted."
            hook_error "Please review the changes."
        fi
        if [ $FAILED_CHECKER -ne 0 ]; then
            hook_error "Some of your changes could not be automatically formatted (see above)."
            hook_error "Please fix them manually."
        fi

        hook_error "Then, add the files and recommit."
        exit 1
    fi

    exit 0
fi

