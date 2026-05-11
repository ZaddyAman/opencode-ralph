#!/bin/bash
# Ralph — Autonomous AI Agent Loop
# FALLBACK: Prefer OpenCode TUI native agent (run `opencode --agent ralph` in project root).
# Usage: ./ralph.sh [--tool opencode|claude] [max_iterations]

set -e

# === Parse arguments ===
TOOL="opencode"
MAX_ITERATIONS=50

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

if [[ "$TOOL" != "opencode" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'opencode' or 'claude'."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"

# === Initialize progress file ===
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Ralph — Autonomous Agent Loop                            ║"
echo "║  Tool: $TOOL                                              ║"
echo "║  Max iterations: $MAX_ITERATIONS"
echo "╚═══════════════════════════════════════════════════════════╝"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Check if all stories are complete
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "?")
  echo "  Remaining stories: $REMAINING"

  if [ "$REMAINING" = "0" ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ALL STORIES COMPLETE!                                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    exit 0
  fi

  # Run the selected AI tool
  if [[ "$TOOL" == "opencode" ]]; then
    OUTPUT=$(opencode run \
      --dangerously-skip-permissions \
      --dir "$PROJECT_DIR" \
      -f "$PROMPT_FILE" \
      "Execute the complete instructions in the attached prompt file. Read and follow every step." \
      2>&1) || true
    echo "$OUTPUT"
  else
    OUTPUT=$(cat "$PROMPT_FILE" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  Ralph completed all tasks at iteration $i!              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    exit 0
  fi

  echo ""
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all stories."
echo "Check $PROGRESS_FILE for status."
echo "Run ralph.sh again to continue."
exit 1
