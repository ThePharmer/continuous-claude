#!/bin/bash

ADDITIONAL_FLAGS="--dangerously-skip-permissions --output-format json"

PROMPT=""
MAX_RUNS=""
ERROR_LOG=""
error_count=0
extra_iterations=0
successful_iterations=0
total_cost=0
i=1

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--prompt)
                PROMPT="$2"
                shift 2
                ;;
            -m|--max-runs)
                MAX_RUNS="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

validate_arguments() {
    if [ -z "$PROMPT" ]; then
        echo "❌ Error: Prompt is required. Use -p to provide a prompt." >&2
        echo "Usage: $0 -p \"your prompt\" -m max_runs" >&2
        exit 1
    fi

    if [ -z "$MAX_RUNS" ]; then
        echo "❌ Error: MAX_RUNS is required. Use -m to provide max runs (0 for infinite)." >&2
        echo "Usage: $0 -p \"your prompt\" -m max_runs" >&2
        exit 1
    fi

    if ! [[ "$MAX_RUNS" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: MAX_RUNS must be a non-negative integer (0 for infinite)" >&2
        exit 1
    fi
}

validate_requirements() {
    if ! command -v claude &> /dev/null; then
        echo "❌ Error: Claude Code is not installed: https://claude.ai/code" >&2
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "⚠️ jq is required for JSON parsing but is not installed. Asking Claude Code to install it..." >&2
        claude -p "Please install jq for JSON parsing" --allowedTools "Bash,Read"
        if ! command -v jq &> /dev/null; then
            echo "❌ Error: jq is still not installed after Claude Code attempt." >&2
            exit 1
        fi
    fi
}

continuous_claude_commit() {
    local iteration_display="$1"
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    fi

    if git diff --quiet && git diff --cached --quiet; then
        echo "🫙 $iteration_display No changes detected" >&2
        return 0
    fi

    echo "💬 $iteration_display Committing changes..." >&2
    
    commit_prompt="Please review the dirty files in the git repository, write a commit message with: (1) a short one-line summary, (2) two newlines, (3) then a detailed explanation. Do not include any footers or metadata like 'Generated with Claude Code' or 'Co-Authored-By'. Feel free to look at the last few commits to get a sense of the commit message style. Track all files and commit the changes using 'git commit -am \"your message\"' (don't push, just commit, no need to ask for confirmation)."
    
    if claude -p "$commit_prompt" --allowedTools "Bash(git)" --dangerously-skip-permissions >/dev/null 2>&1; then
        if git diff --quiet && git diff --cached --quiet; then
            echo "📦 $iteration_display Changes committed" >&2
        else
            echo "⚠️  $iteration_display Commit command ran but changes still present" >&2
        fi
    else
        echo "⚠️  $iteration_display Failed to commit changes" >&2
    fi
}

get_iteration_display() {
    local iteration_num=$1
    local max_runs=$2
    local extra_iters=$3
    
    if [ $max_runs -eq 0 ]; then
        echo "($iteration_num)"
    else
        local total=$((max_runs + extra_iters))
        echo "($iteration_num/$total)"
    fi
}

run_claude_iteration() {
    local prompt="$1"
    local flags="$2"
    local error_log="$3"
    
    claude -p "$prompt" $flags 2>"$error_log"
}

parse_claude_result() {
    local result="$1"
    
    if ! echo "$result" | jq -e . >/dev/null 2>&1; then
        echo "invalid_json"
        return 1
    fi
    
    local is_error=$(echo "$result" | jq -r '.is_error // false')
    if [ "$is_error" = "true" ]; then
        echo "claude_error"
        return 1
    fi
    
    echo "success"
    return 0
}

handle_iteration_error() {
    local iteration_display="$1"
    local error_type="$2"
    local error_output="$3"
    
    error_count=$((error_count + 1))
    extra_iterations=$((extra_iterations + 1))
    
    case "$error_type" in
        "exit_code")
            echo "❌ $iteration_display Error occurred ($error_count consecutive errors):" >&2
            cat "$ERROR_LOG" >&2
            ;;
        "invalid_json")
            echo "❌ $iteration_display Error: Invalid JSON response ($error_count consecutive errors):" >&2
            echo "$error_output" >&2
            ;;
        "claude_error")
            echo "❌ $iteration_display Error in Claude Code response ($error_count consecutive errors):" >&2
            echo "$error_output" | jq -r '.result // .' >&2
            ;;
    esac
    
    if [ $error_count -ge 3 ]; then
        echo "❌ Fatal: 3 consecutive errors occurred. Exiting." >&2
        exit 1
    fi
    
    return 1
}

handle_iteration_success() {
    local iteration_display="$1"
    local result="$2"
    
    error_count=0
    if [ $extra_iterations -gt 0 ]; then
        extra_iterations=$((extra_iterations - 1))
    fi
    
    echo "📝 $iteration_display Output:" >&2
    local result_text=$(echo "$result" | jq -r '.result // empty')
    if [ -n "$result_text" ]; then
        echo "$result_text"
    else
        echo "(no output)" >&2
    fi

    local cost=$(echo "$result" | jq -r '.total_cost_usd // empty')
    if [ -n "$cost" ]; then
        echo "" >&2
        printf "💰 $iteration_display Cost: \$%.3f\n" "$cost" >&2
        total_cost=$(awk "BEGIN {printf \"%.3f\", $total_cost + $cost}")
    fi

    echo "✅ $iteration_display Work completed" >&2
    continuous_claude_commit "$iteration_display"
    successful_iterations=$((successful_iterations + 1))
}

execute_single_iteration() {
    local iteration_num=$1
    
    local iteration_display=$(get_iteration_display $iteration_num $MAX_RUNS $extra_iterations)
    echo "🔄 $iteration_display Starting iteration..." >&2

    local result
    if ! result=$(run_claude_iteration "$PROMPT" "$ADDITIONAL_FLAGS" "$ERROR_LOG"); then
        handle_iteration_error "$iteration_display" "exit_code" ""
        return 1
    fi
    
    if [ -s "$ERROR_LOG" ]; then
        echo "⚠️  $iteration_display Warnings or errors in stderr:" >&2
        cat "$ERROR_LOG" >&2
    fi
    
    local parse_result=$(parse_claude_result "$result")
    if [ "$?" != "0" ]; then
        handle_iteration_error "$iteration_display" "$parse_result" "$result"
        return 1
    fi
    
    handle_iteration_success "$iteration_display" "$result"
    return 0
}

main_loop() {
    while [ $MAX_RUNS -eq 0 ] || [ $successful_iterations -lt $MAX_RUNS ]; do
        execute_single_iteration $i
        
        if [ $MAX_RUNS -eq 0 ] || [ $successful_iterations -lt $MAX_RUNS ]; then
            sleep 1
        fi
        
        i=$((i + 1))
    done
}

show_completion_summary() {
    if [ $MAX_RUNS -ne 0 ]; then
        if [ -n "$total_cost" ] && [ "$(awk "BEGIN {print ($total_cost > 0)}")" = "1" ]; then
            printf "🎉 Done with total cost: \$%.3f\n" "$total_cost"
        else 
            echo "🎉 Done"
        fi
    fi
}

main() {
    parse_arguments "$@"
    validate_arguments
    validate_requirements
    
    ERROR_LOG=$(mktemp)
    trap "rm -f $ERROR_LOG" EXIT
    
    main_loop
    show_completion_summary
}

if [ -z "$TESTING" ]; then
    main "$@"
fi
