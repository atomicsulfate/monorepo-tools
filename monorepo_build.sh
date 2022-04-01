#!/usr/bin/env bash

# Build monorepo from specified remotes
# You must first add the remotes by "git remote add <remote-name> <repository-url>".
# Final monorepo will contain all branches and tags from all remotes, merging those with the same
# name.
# If subdirectory is not specified remote name will be used instead
#
# Usage: monorepo_build.sh <remote-name>[:<subdirectory>] <remote-name>[:<subdirectory>] ...
#
# Example: monorepo_build.sh main-repository package-alpha:packages/alpha package-beta:packages/beta

# Skip git filter-branch warning.
export FILTER_BRANCH_SQUELCH_WARNING=1

function remote_branches {
	git branch -r --list $1/*| sed -e "s/[ \t]*$1\///"
}

function fetch_tags_from_remote {
    REMOTE=$1
    # Delete all local tags to avoid conflicts with tags from other remotes.
    git tag -d $(git tag -l) > /dev/null

    git fetch $REMOTE --tags
}

function get_remote_from_rev {
    BRANCH=$(head -n 1 <<< $(git branch -r --contains $1))
    echo ${BRANCH%%/*}
}

function document_merge {
    REV_LINES=$(sed -e 's/\s\+/\n/g'  <<< "$1") # Split into one rev per line.
    RESULT=""
    # Prepend remote name to each rev.
    for REV in $REV_LINES; do
        RESULT+="$(get_remote_from_rev $REV) $REV"$'\n'
    done
    echo "$RESULT"
}

function merge_revs_in_current {
    REF=$1
    REVS=(${@:2})
    REVS_STR="${REVS[@]}"
    NUM_REVS=${#REVS[@]}
    MERGE_DOC=`document_merge "$REVS_STR"`

    echo -e "\t\t$REF, $NUM_REVS revs:\n$(sed 's/^/\t\t\t/' <<< $MERGE_DOC)"

    # Just one revision, no need to merge.
    if [[ $NUM_REVS -eq 1 ]]; then
        return
    fi

    COMMIT_MSG="Merge $REF from all repos into monorepo. Revs:"$'\n'"$MERGE_DOC"
    git merge --no-commit -q $REVS_STR --allow-unrelated-histories > /dev/null
    # Resolving conflicts using trees of all parents
    for REV in $REVS_STR; do
        # Add all files from all master branches into index
        # "git read-tree" with multiple refs cannot be used as it is limited to 8 refs
        git ls-tree -r $REV | git update-index --index-info  > /dev/null
    done
    git commit -m "$COMMIT_MSG" > /dev/null
    git reset --hard  > /dev/null
}

function cleanup-local {
    # Checking out orphan commit so it 's possible to delete current branch
    git checkout -q --orphan void
    git reset --hard > /dev/null
    git clean -fdx > /dev/null
    for BRANCH in $(git branch); do
        git branch -D $BRANCH > /dev/null
    done
}

# Check provided arguments
if [ "$#" -lt "2" ]; then
    echo 'Please provide at least 2 remotes to be merged into a new monorepo'
    echo 'Usage: monorepo_build.sh <remote-name>[:<subdirectory>] <remote-name>[:<subdirectory>] ...'
    echo 'Example: monorepo_build.sh main-repository package-alpha:packages/alpha package-beta:packages/beta'
    exit
fi
# Get directory of the other scripts
MONOREPO_SCRIPT_DIR=$(dirname "$0")
# Wipe original refs (possible left-over back-up after rewriting git history)
$MONOREPO_SCRIPT_DIR/original_refs_wipe.sh > /dev/null

declare -A MERGE_BRANCHES
declare -A MERGE_TAGS

cleanup-local > /dev/null

echo "1. Rewrite history for all refs (branch and tags) across all remotes"

for PARAM in $@; do
    # Parse parameters in format <remote-name>[:<subdirectory>]
    PARAM_ARR=(${PARAM//:/ })
    REMOTE=${PARAM_ARR[0]}
    SUBDIRECTORY=${PARAM_ARR[1]}
    if [ "$SUBDIRECTORY" == "" ]; then
        SUBDIRECTORY=$REMOTE
    fi
    echo -e "\tRemote '$REMOTE'"
    echo -e "\t\tFetch all tags"
    fetch_tags_from_remote $REMOTE
    echo -e "\t\tRewrite history to move files into subdir '$SUBDIRECTORY'"
    # git filter-branch needs some valid HEAD.
    git checkout -q -B master $(git rev-parse $REMOTE/master)
    $MONOREPO_SCRIPT_DIR/rewrite_history_into.sh $SUBDIRECTORY --remotes=$REMOTE --tags
    cleanup-local > /dev/null

    for BRANCH in $(remote_branches $REMOTE); do
        MERGE_BRANCHES[$BRANCH]="${MERGE_BRANCHES[$BRANCH]} $(git rev-parse $REMOTE/$BRANCH)"
    done

    for TAG in $(git tag -l); do
        MERGE_TAGS[$TAG]="${MERGE_TAGS[$TAG]} $(git rev-parse $TAG)"
        git tag -d $TAG > /dev/null # clean up to avoid conflicts with tags from next remote.
    done
    # Wipe the back-up of original history
    $MONOREPO_SCRIPT_DIR/original_refs_wipe.sh > /dev/null
done

echo "2. Merge branches and tags with same names across remotes"

echo -e "\tMerge Branches"
for BRANCH in "${!MERGE_BRANCHES[@]}"; do
    REVS=(${MERGE_BRANCHES[$BRANCH]})
    FIRST_REV=${REVS[0]}
    git checkout -q -b $BRANCH $FIRST_REV

    merge_revs_in_current $BRANCH ${REVS[@]}
done

echo -e "\tMerge Tags"
for TAG in "${!MERGE_TAGS[@]}"; do
    REVS=(${MERGE_TAGS[$TAG]})
    FIRST_REV=${REVS[0]}

    # Create a temporal branch to do the merge.
    TMP_BRANCH="${TAG}_tmpBranch"
    git checkout -q -b $TMP_BRANCH $FIRST_REV

    merge_revs_in_current $TAG ${REVS[@]}

    # Create the tag from the tmp branch and delete branch.
    git tag -f $TAG > /dev/null
    git checkout -q $TAG
    git branch -q -D $TMP_BRANCH
done

echo "3. Review created branches and tags. If all's well, push with 'git push --all <monorepo_remote> && git push --tags <monorepo_remote>'"


