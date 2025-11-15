# 🔂 Continuous Claude

Automated wrapper for Claude Code that continuously executes tasks with automatic git commits, PR creation, CI/CD integration, and intelligent error handling.

## ⚙️ How it works

When you have a task like "Add unit tests until all code is covered", you want to run Claude Code repeatedly until all code is covered. This script does that for you:

- Claude Code runs in a loop based on your prompt
- All changes are committed to a new branch
- A new pull request is created
- It waits for all required PR checks to pass
- Once checks are successful, the PR is merged
- This process repeats until your task is complete

## 🚀 Quick start

Make sure you have Claude Code CLI and GitHub CLI installed and authenticated. Then:

```bash
# Download the script
curl -o continuous_claude.sh https://raw.githubusercontent.com/AnandChowdhary/continuous-claude/refs/heads/main/continuous_claude.sh

# Make it executable
chmod +x continuous_claude.sh

# Run it with your prompt, infinite max runs, and GitHub repo
./continuous_claude.sh --prompt "add unit tests until all code is covered" --max-runs 0 --owner AnandChowdhary --repo continuous-claude
```

## 🎯 Flags

- `-p, --prompt`: Task prompt for Claude Code (required)
- `-m, --max-runs`: Number of iterations, use `0` for infinite (required)
- `--owner`: GitHub repository owner (required)
- `--repo`: GitHub repository name (required)
- `--git-branch-prefix`: Prefix for git branch names (default: `continuous-claude/`)
- `--disable-commits`: Disable automatic git commits, PR creation, and merging (useful for testing)

## 📝 Examples

```bash
# Run 5 iterations
./continuous_claude.sh -p "improve code quality" -m 5 --owner AnandChowdhary --repo continuous-claude

# Run infinitely until stopped
./continuous_claude.sh -p "add unit tests until all code is covered" -m 0 --owner AnandChowdhary --repo continuous-claude

# Use custom branch prefix
./continuous_claude.sh -p "refactor code" -m 3 --owner AnandChowdhary --repo continuous-claude --git-branch-prefix "feature/"

# Test without creating commits or PRs
./continuous_claude.sh -p "test changes" -m 2 --owner AnandChowdhary --repo continuous-claude --disable-commits
```

## 📃 License

MIT (c) [Anand Chowdhary](https://anandchowdhary.com)
