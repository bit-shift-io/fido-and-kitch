#!/bin/bash
# code-review/prepare.sh
# Prepares metadata for code review: branch info, base branch, ClickUp URLs, file changes, git state validation
# Outputs structured JSON to reduce token usage and git command overhead

set -e

# Color codes for error output
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function to output JSON
output_json() {
    local branch="$1"
    local base_branch="$2"
    local task_id="$3"
    local working_tree_clean="$4"
    local remote_tracked="$5"
    local commits="$6"
    local clickup_urls="$7"
    local changed_files="$8"
    local file_count="$9"
    local total_changes="${10}"

    cat <<EOF
{
  "branch": "$branch",
  "base_branch": "$base_branch",
  "task_id": "$task_id",
  "working_tree_clean": $working_tree_clean,
  "remote_tracked": $remote_tracked,
  "commits": $commits,
  "clickup_urls": $clickup_urls,
  "changed_files": $changed_files,
  "file_count": $file_count,
  "total_changes": "$total_changes"
}
EOF
}

# Detect current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}" >&2
    exit 1
fi

# Detect base branch
BASE_BRANCH=$(git log --format="%D" HEAD 2>/dev/null | tr ',' '\n' | grep -oE 'origin/(master|production|beta|main)' | head -1 | sed 's/origin\///')
if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH="master"
fi

# Extract ClickUp task ID from branch name (last segment after dash, if dev/* branch)
TASK_ID=""
if [[ "$BRANCH" =~ ^dev/ ]]; then
    TASK_ID=$(echo "$BRANCH" | grep -oE '[a-z0-9]+$' || echo "")
fi

# Check if working tree is clean (0 = clean, 1 = dirty)
# Exclude .claude/commands/code-review/ since it's skill infrastructure, not user code
WORKING_TREE_CLEAN=0
DIRTY_FILES=$(git status --porcelain 2>/dev/null | grep -v '\.claude/commands/code-review' || true)
if [ -n "$DIRTY_FILES" ]; then
    WORKING_TREE_CLEAN=1
fi

# Check if branch tracks a remote (0 = not tracked, 1 = tracked)
REMOTE_TRACKED=0
if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null 2>&1; then
    REMOTE_TRACKED=1
fi

# Get commits between base and HEAD
COMMITS_ARRAY=$(git log "$BASE_BRANCH"...HEAD --oneline 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')

# Extract ClickUp URLs from commit messages
CLICKUP_URLS=$(git log "$BASE_BRANCH"...HEAD --pretty=format:%b%s 2>/dev/null | grep -oE 'https://app.clickup.com/t/[a-z0-9]+' | sort -u)
if [ -n "$CLICKUP_URLS" ]; then
    CLICKUP_URLS_ARRAY=$(echo "$CLICKUP_URLS" | jq -R . | jq -s .)
else
    CLICKUP_URLS_ARRAY="[]"
fi

# Get changed files
CHANGED_FILES_ARRAY=$(git diff "$BASE_BRANCH"...HEAD --name-only 2>/dev/null | jq -R . | jq -s . || echo "[]")

# Count changed files
FILE_COUNT=$(git diff "$BASE_BRANCH"...HEAD --name-only 2>/dev/null | wc -l)

# Get total changes (insertions + deletions)
TOTAL_CHANGES=$(git diff "$BASE_BRANCH"...HEAD --shortstat 2>/dev/null | grep -oE '[0-9]+ (insertion|deletion|file changed)' | tr '\n' ', ' | sed 's/,$//')
[ -z "$TOTAL_CHANGES" ] && TOTAL_CHANGES="No changes"

# Output structured JSON
output_json "$BRANCH" "$BASE_BRANCH" "$TASK_ID" "$WORKING_TREE_CLEAN" "$REMOTE_TRACKED" "$COMMITS_ARRAY" "$CLICKUP_URLS_ARRAY" "$CHANGED_FILES_ARRAY" "$FILE_COUNT" "$TOTAL_CHANGES"
