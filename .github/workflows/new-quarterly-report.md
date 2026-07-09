---
description: Quarterly contribution impact report for the adoptium org. Data is fetched and aggregated deterministically; the agent only ranks and writes.
on:
  schedule:
    - cron: "0 9 * * 1"
  workflow_dispatch:
    inputs:
      start_date:
        description: "Start date (YYYY-MM-DD). Leave empty to default to 90 days ago."
        required: false
        default: ""
      end_date:
        description: "End date (YYYY-MM-DD). Leave empty to default to today."
        required: false
        default: ""
engine:
  id: copilot
timeout-minutes: 30
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write
network:
  allowed:
    - defaults
steps:
  - name: Fetch and aggregate quarterly contribution data
    env:
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: |
      set -euo pipefail
      mkdir -p /tmp/gh-aw/agent

      START_DATE="${{ inputs.start_date }}"
      if [ -z "$START_DATE" ]; then
        SINCE=$(date -u -d '90 days ago' '+%Y-%m-%d')
      else
        SINCE=$START_DATE
      fi

      END_DATE="${{ inputs.end_date }}"
      if [ -z "$END_DATE" ]; then
        UNTIL=$(date -u '+%Y-%m-%d')
      else
        UNTIL=$END_DATE
      fi

      echo "Window start: $SINCE"
      echo "Window end: $UNTIL"

      # Fetch merged PRs with body field to detect Copilot PRs and linked issues
      gh api -X GET search/issues \
        -f q="org:adoptium is:pr is:merged merged:>=$SINCE...$UNTIL" \
        -f per_page=100 --paginate \
        --jq '.items[] | {number, title, user: .user.login, repo: (.repository_url | sub("https://api.github.com/repos/"; "")), merged: .pull_request.merged_at, body: .body}' \
        | jq -s '.' > /tmp/gh-aw/agent/merged-prs.json

      # Fetch closed issues
      gh api -X GET search/issues \
        -f q="org:adoptium is:issue is:closed closed:>=$SINCE...$UNTIL" \
        -f per_page=100 --paginate \
        --jq '.items[] | {number, title, user: .user.login, repo: (.repository_url | sub("https://api.github.com/repos/"; ""))}' \
        | jq -s '.' > /tmp/gh-aw/agent/closed-issues.json

      # For each Copilot-authored PR, find who triggered it by looking at linked issue assignees
      jq -r '.[] | select(.user | test("copilot|bot"; "i")) | .repo + " " + (.number | tostring)' \
        /tmp/gh-aw/agent/merged-prs.json > /tmp/gh-aw/agent/bot-prs.txt || true

      echo "[]" > /tmp/gh-aw/agent/copilot-attribution.json
      if [ -s /tmp/gh-aw/agent/bot-prs.txt ]; then
        while IFS=' ' read -r repo pr_number; do
          # Get the linked issue number from the PR body (looks for "Fixes #123" or "Closes #123")
          pr_body=$(jq -r --arg repo "$repo" --argjson num "$pr_number" \
            '.[] | select(.repo == $repo and .number == $num) | .body // ""' \
            /tmp/gh-aw/agent/merged-prs.json)
          linked_issue=$(echo "$pr_body" | grep -oP '(?i)(fixes|closes|resolves)\s+#\K[0-9]+' | head -1 || true)
          if [ -n "$linked_issue" ]; then
            # Get assignees from the linked issue
            assignees=$(gh api "repos/$repo/issues/$linked_issue" \
              --jq '[.assignees[].login] | join(", ")' 2>/dev/null || echo "unknown")
            human_trigger=$(echo "$assignees" | tr ',' '\n' | grep -iv 'copilot\|bot' | head -1 | tr -d ' ' || echo "unknown")
          else
            human_trigger="unknown"
          fi
          jq --arg repo "$repo" --argjson num "$pr_number" --arg trigger "$human_trigger" \
            '. += [{repo: $repo, pr_number: $num, triggered_by: $trigger}]' \
            /tmp/gh-aw/agent/copilot-attribution.json > /tmp/gh-aw/agent/tmp.json
          mv /tmp/gh-aw/agent/tmp.json /tmp/gh-aw/agent/copilot-attribution.json
        done < /tmp/gh-aw/agent/bot-prs.txt
      fi

      # Build summary
      jq -n \
        --slurpfile prs /tmp/gh-aw/agent/merged-prs.json \
        --slurpfile iss /tmp/gh-aw/agent/closed-issues.json \
        --slurpfile attribution /tmp/gh-aw/agent/copilot-attribution.json \
        '{
          window_start: "'"$SINCE"'",
          window_end: "'"$UNTIL"'",
          total_merged_prs: ($prs[0] | length),
          total_closed_issues: ($iss[0] | length),
          repos_touched: ([$prs[0][].repo] | unique | length),
          prs_by_repo: ([$prs[0][].repo] | group_by(.) | map({repo: .[0], count: length}) | sort_by(-.count)),
          contributors: ([$prs[0][].user] | group_by(.) | map({user: .[0], merged_prs: length}) | sort_by(-.merged_prs)),
          copilot_attribution: $attribution[0]
        }' > /tmp/gh-aw/agent/summary.json

      echo "=== summary.json ==="
      cat /tmp/gh-aw/agent/summary.json
safe-outputs:
  create-issue:
    title-prefix: "[quarterly-impact] "
    labels: [report, quarterly-impact]
    close-older-issues: true
---

# Quarterly Contribution Impact Report

All GitHub data has already been fetched and aggregated for you before this step. Do NOT call any GitHub tools or shell commands to fetch data — everything you need is on disk.

## Pre-fetched data
- `/tmp/gh-aw/agent/summary.json` — pre-computed aggregates: totals, PRs grouped by repository, contributors ranked by merged-PR count, and Copilot attribution data.
- `/tmp/gh-aw/agent/merged-prs.json` — the full list of merged PRs (number, title, author, repo, body) for detail in the highlights.
- `/tmp/gh-aw/agent/closed-issues.json` — closed issues over the window.
- `/tmp/gh-aw/agent/copilot-attribution.json` — for each bot/Copilot PR, who triggered it.

## Your task
Using only the files above, write a concise quarterly contribution impact report and create exactly one GitHub issue in this repository.

The contributors in `summary.json` are already ranked by merged-PR count. Treat that count as the base signal, but you may adjust the narrative ranking using PR titles in `merged-prs.json` where a contributor's work is clearly higher-impact. State your reasoning briefly.

For any contributor whose username contains "copilot" or "bot", check `copilot-attribution.json` and show who triggered or guided that bot instead of just listing the bot name.

## The issue must contain
- A header summary: window covered, total merged PRs, total closed issues, and number of distinct repositories touched.
- A ranked list of the top contributors by estimated impact, each with their merged-PR count and a one-line justification. For bot contributors, show "triggered by @[human]" next to their name.
- A "Top 10 contributions" highlight section drawn from `merged-prs.json`, chosen for apparent impact based on titles.
- An "Activity by repository" section from `prs_by_repo`, listing the most active repositories.
- Suggested next steps or items needing maintainer attention for the next quarter.

## Constraints
- Create exactly one issue.
- Do not fetch any additional data; rank and summarize only what is on disk.
- Impact scoring is heuristic; flag anything that may warrant human review.
- Keep it concise and skimmable.


