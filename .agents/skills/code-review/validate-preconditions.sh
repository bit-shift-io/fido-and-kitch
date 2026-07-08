#!/bin/bash
# code-review/validate-preconditions.sh
# Validates that the repository is in a valid state for code review
# Exits with error code if any preconditions fail

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA=$(bash "$SCRIPT_DIR/prepare.sh")

# Helper to extract JSON values
get_json_value() {
    echo "$METADATA" | jq -r ".$1"
}

BRANCH=$(get_json_value 'branch')
BASE_BRANCH=$(get_json_value 'base_branch')
WORKING_CLEAN=$(get_json_value 'working_tree_clean')
REMOTE_TRACKED=$(get_json_value 'remote_tracked')
COMMIT_COUNT=$(get_json_value 'commits | length')
FILE_COUNT=$(get_json_value 'file_count')

echo "📋 Code Review Pre-flight Check"
echo "================================"
echo ""

# Check 1: Working tree is clean
echo -n "✓ Working tree clean: "
if [ "$WORKING_CLEAN" = "0" ]; then
    echo "✅ Yes"
else
    echo "❌ No - uncommitted changes present"
    git status --short
    echo ""
    echo "⚠️  Commit or stash changes before running code review."
    exit 1
fi

# Check 2: Branch is tracking a remote
echo -n "✓ Remote tracking: "
if [ "$REMOTE_TRACKED" = "1" ]; then
    echo "✅ Yes"
else
    echo "⚠️  No remote tracking configured"
fi

# Check 3: There are commits to review
echo -n "✓ Commits to review: "
if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "✅ Yes ($COMMIT_COUNT commits)"
else
    echo "❌ No commits found between $BRANCH and $BASE_BRANCH"
    exit 1
fi

# Check 4: There are files changed
echo -n "✓ Files changed: "
if [ "$FILE_COUNT" -gt 0 ]; then
    echo "✅ Yes ($FILE_COUNT files)"
else
    echo "⚠️  No files changed"
fi

echo ""
echo "Summary:"
echo "--------"
echo "Branch:      $BRANCH"
echo "Base:        $BASE_BRANCH"
echo "Commits:     $COMMIT_COUNT"
echo "Files:       $FILE_COUNT"
echo ""
echo "✅ All preconditions passed. Ready for code review."
echo ""
echo "Run: /code-review"
