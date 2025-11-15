# 🔂 Continuous Claude

Automated wrapper for Claude Code that runs tasks repeatedly with automatic git commits and error handling.

## 🚀 Quick start

```bash
./run_claude.sh -p "your prompt" -m max_runs
```

## 🎯 Flags

- `-p, --prompt`: Task prompt for Claude Code (required)
- `-m, --max-runs`: Number of iterations, use `0` for infinite (required)

## 📝 Examples

```bash
# Run 5 iterations
./run_claude.sh -p "improve code quality" -m 5

# Run infinitely until stopped
./run_claude.sh -p "add unit tests until all code is covered" -m 0
```

## 📃 License

MIT (c) [Anand Chowdhary](https://anandchowdhary.com)
