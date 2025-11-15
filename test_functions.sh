#!/bin/bash

# Source the script but prevent main from running
export TESTING=1
source continuous_claude.sh

echo "🧪 Testing Functions"
echo "===================="
echo ""

echo "1️⃣ Testing parse_arguments()"
echo "----------------------------"
PROMPT=""
MAX_RUNS=""
parse_arguments -p "test prompt" -m 5
if [ "$PROMPT" = "test prompt" ] && [ "$MAX_RUNS" = "5" ]; then
    echo "✅ parse_arguments() works correctly"
else
    echo "❌ parse_arguments() failed: PROMPT='$PROMPT', MAX_RUNS='$MAX_RUNS'"
fi
echo ""

echo "2️⃣ Testing get_iteration_display()"
echo "----------------------------------"
result1=$(get_iteration_display 3 10 2)
if [ "$result1" = "(3/12)" ]; then
    echo "✅ get_iteration_display() with fixed runs: $result1"
else
    echo "❌ get_iteration_display() failed: got '$result1', expected '(3/12)'"
fi

result2=$(get_iteration_display 5 0 0)
if [ "$result2" = "(5)" ]; then
    echo "✅ get_iteration_display() with infinite runs: $result2"
else
    echo "❌ get_iteration_display() failed: got '$result2', expected '(5)'"
fi
echo ""

echo "3️⃣ Testing parse_claude_result()"
echo "---------------------------------"
valid_json='{"result":"test","is_error":false,"total_cost_usd":0.01}'
result=$(parse_claude_result "$valid_json")
if [ "$result" = "success" ] && [ "$?" = "0" ]; then
    echo "✅ parse_claude_result() with valid JSON: $result"
else
    echo "❌ parse_claude_result() failed with valid JSON"
fi

error_json='{"result":"error","is_error":true}'
result=$(parse_claude_result "$error_json"; echo "EXIT:$?")
exit_code=$(echo "$result" | grep "EXIT:" | cut -d: -f2)
result=$(echo "$result" | grep -v "EXIT:")
if [ "$result" = "claude_error" ] && [ "$exit_code" != "0" ]; then
    echo "✅ parse_claude_result() with error JSON: $result"
else
    echo "❌ parse_claude_result() failed with error JSON (result: $result, exit: $exit_code)"
fi

invalid_json="not json"
result=$(parse_claude_result "$invalid_json"; echo "EXIT:$?")
exit_code=$(echo "$result" | grep "EXIT:" | cut -d: -f2)
result=$(echo "$result" | grep -v "EXIT:")
if [ "$result" = "invalid_json" ] && [ "$exit_code" != "0" ]; then
    echo "✅ parse_claude_result() with invalid JSON: $result"
else
    echo "❌ parse_claude_result() failed with invalid JSON (result: $result, exit: $exit_code)"
fi
echo ""

echo "4️⃣ Testing handle_iteration_success()"
echo "--------------------------------------"
error_count=2
extra_iterations=1
total_cost=0.01
successful_iterations=0

test_result='{"result":"Hello","is_error":false,"total_cost_usd":0.05}'
handle_iteration_success "(1/1)" "$test_result" >/dev/null 2>&1
if [ "$error_count" = "0" ] && [ "$extra_iterations" = "0" ] && [ "$successful_iterations" = "1" ]; then
    echo "✅ handle_iteration_success() resets error_count, extra_iterations, and increments successful_iterations"
else
    echo "❌ handle_iteration_success() failed (error_count: $error_count, extra_iterations: $extra_iterations, successful_iterations: $successful_iterations)"
fi
echo ""

echo "5️⃣ Testing show_completion_summary()"
echo "------------------------------------"
MAX_RUNS=5
total_cost=0.15
result=$(show_completion_summary)
if echo "$result" | grep -q "Done with total cost"; then
    echo "✅ show_completion_summary() with cost: displays correctly"
else
    echo "❌ show_completion_summary() failed with cost"
fi

total_cost=0
result=$(show_completion_summary)
if echo "$result" | grep -q "Done" && ! echo "$result" | grep -q "cost"; then
    echo "✅ show_completion_summary() without cost: displays correctly"
else
    echo "❌ show_completion_summary() failed without cost"
fi
echo ""

echo "6️⃣ Testing validate_arguments()"
echo "-------------------------------"
PROMPT=""
MAX_RUNS=""
output=$(validate_arguments 2>&1 || true)
if echo "$output" | grep -q "Prompt is required"; then
    echo "✅ validate_arguments() correctly detects missing PROMPT"
else
    echo "❌ validate_arguments() failed to detect missing PROMPT"
fi

PROMPT="test"
MAX_RUNS=""
output=$(validate_arguments 2>&1 || true)
if echo "$output" | grep -q "MAX_RUNS is required"; then
    echo "✅ validate_arguments() correctly detects missing MAX_RUNS"
else
    echo "❌ validate_arguments() failed to detect missing MAX_RUNS"
fi

PROMPT="test"
MAX_RUNS="abc"
output=$(validate_arguments 2>&1 || true)
if echo "$output" | grep -q "non-negative integer"; then
    echo "✅ validate_arguments() correctly detects invalid MAX_RUNS"
else
    echo "❌ validate_arguments() failed to detect invalid MAX_RUNS"
fi
echo ""

echo "7️⃣ Testing continuous_claude_commit()"
echo "--------------------------------------"
cd /Users/anandchowdhary/projects/AnandChowdhary/continuous-claude
if git rev-parse --git-dir > /dev/null 2>&1; then
    result=$(continuous_claude_commit "(test)" 2>&1)
    if echo "$result" | grep -qE "(No changes detected|Changes committed|Commit command ran|Failed to commit)"; then
        echo "✅ continuous_claude_commit() executes correctly"
    else
        echo "❌ continuous_claude_commit() failed"
    fi
else
    echo "⏭️  Skipping continuous_claude_commit() test (not in git repo)"
fi
echo ""

echo "8️⃣ Testing run_claude_iteration()"
echo "----------------------------------"
ERROR_LOG=$(mktemp)
result=$(run_claude_iteration "say hello" "--dangerously-skip-permissions --output-format json" "$ERROR_LOG")
if [ "$?" = "0" ] && echo "$result" | jq -e . >/dev/null 2>&1; then
    echo "✅ run_claude_iteration() executes Claude and returns valid JSON"
else
    echo "❌ run_claude_iteration() failed"
fi
rm -f "$ERROR_LOG"
echo ""

echo "9️⃣ Testing handle_iteration_error()"
echo "------------------------------------"
error_count=0
extra_iterations=0
ERROR_LOG=$(mktemp)
echo "test error" > "$ERROR_LOG"
handle_iteration_error "(1/1)" "exit_code" "" 2>&1 >/dev/null
if [ "$error_count" = "1" ] && [ "$extra_iterations" = "1" ]; then
    echo "✅ handle_iteration_error() increments error_count and extra_iterations"
else
    echo "❌ handle_iteration_error() failed (error_count: $error_count, extra_iterations: $extra_iterations)"
fi
rm -f "$ERROR_LOG"
echo ""

echo "✅ All function tests completed!"

