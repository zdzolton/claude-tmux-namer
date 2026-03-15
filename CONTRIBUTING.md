# Contributing

This project was vibed into existence and it stays that way.

## The rule

All contributions must be AI-generated. Do not read the source code. Do not write code by hand. Describe what you want to an LLM and submit what it gives you.

This isn't a joke. It's the whole point. The tmux namer is the dumbest thing I could get working while barely trying. If your contribution requires understanding the codebase, you're doing it wrong.

## How to contribute

1. Find something broken or annoying.
2. Describe the problem to your preferred coding agent.
3. Let it generate a fix.
4. Open a PR with what it gave you.

Include the prompt you used or a summary of the conversation. This is more useful than code comments.

## What's welcome

- Bug reports. Always welcome, no vibing required.
- Cost reduction ideas. The tool calls Haiku via `--continue` which sends the entire session context. Cached calls are ~$0.003 but uncached hits are ~$0.03-0.05. Cheaper approaches are interesting.
- Robustness fixes. It stops working sometimes. That's annoying.
- Better behavior during long context sessions. Haiku doesn't support long context, so the namer fails on 1M context windows with "Prompt is too long." Graceful degradation here would be nice.
- A local model alternative for the summarization step. Bigger lift but would eliminate API costs entirely.

## What's not welcome

- Hand-written code.
- Refactors for the sake of refactoring. It's ~50 lines of zsh.
- Adding dependencies.
- Scope creep. It renames tmux windows. That's it.

## Project structure

```
.claude-plugin/    # Plugin manifest
scripts/           # The actual zsh script
.github/workflows/ # CI (plugin validation)
Makefile           # install/uninstall targets
```

## Validating changes

```
make install
```

The plugin validates via a GitHub Actions workflow. Cost data logs to `~/.local/share/claude-tmux-namer/cost.log` if you need to check your work isn't blowing up the bill.

## PRs

I'll review PRs when I get to them. Don't take slow responses personally. This is a side project I maintain in the margins.
