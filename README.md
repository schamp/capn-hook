# capn-hook

A set of sh scripts for managing repo state for git hooks, primarily, pre-commit or pre-push hooks.

It is based originally on this [stack overflow answer](http://stackoverflow.com/a/20480591/1606867)
but has been heavily modified.

## Usage

It is meant for use with services like [git-hooks-js](https://github.com/tarmolov/git-hooks-js),
which keeps it hook scripts in separate folders with the hook name, e.g.:

  * `.githooks/pre-commit`
  * `.githooks/post-commit`
 
and which runs hooks in sorted order by name.

To use for pre-commit, make sure that 000-stash.sh runs before your hooks 
(which can be kept in separate files for simplicity) and that 999-unstash.sh
runs after your hooks.

## Operation

The goal is to set the working state of the repo to match the changes staged for commit,
so that hooks can run on the work tree as-is.  It also supports hooks which change the 
working state of the repo (such as code beautifiers), allowing the user the opportunity
to add the modified files and retry the commit.  After the commit succeeds, it restores
the state of the working tree, where possible.  There are many edge cases with potential
conflicts, which capn-hook handles by tracking the stash and warning the user.  Standard
workflows should work without any complications.

It also properly handles untracked files, removing them while the scripts run, and then
restoring them after.  This helps prevent builds and tests from passing and other issues
due to files that have erroneously not been added to the repo.

It uses a `.hookstate` file to track the state of the repo from between the stash and the
unstash scripts.  It pushes things onto the stack with specific names.

If you elect to use the `stash-cleanup.sh` post-commit hook, it will alert the user if
any state from the user remains on the stash after the commit succeeds.

## Designing hooks

Because the working tree matches the changes to be committed, the hooks can operate
on them without having to juggle state or in-work changes.  For example, run a formatter
or a white-space fixer.  To check whether your tool run changed any files (in case it 
doesn't tell you), you can just check the current state of the repo against the index,
e.g. `git diff --name-only`.  It's probably a good idea to exit the hook with status 1
and print a helpful message, so that the user knows action is required (approve or reject
the changes and retry the commit).

Try using environment variables to affect the behavior of your hooks, since there is no
way to interact with the user as they are running.

## Installation

To install with git-hooks-js, just copy the contents of the hooks subfolders 
into the corresponding .githooks folders managed by git-hooks-js

To install with other hook managers, add `000-stash.sh` as the first pre-commit hook, 
and `999-unstash.sh` as the last pre-commit hook.

## Test

To test, run `npm install` to install the `git-hooks` dependency and then `npm test`
to run the test script.
