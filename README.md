# claude-tmux-namer

[![Validate Plugin](https://github.com/cosgroveb/claude-tmux-namer/actions/workflows/validate.yml/badge.svg)](https://github.com/cosgroveb/claude-tmux-namer/actions/workflows/validate.yml)

A Claude Code plugin that automatically renames your tmux window with a short phrase describing your current work.

<img width="519" height="117" alt="image" src="https://github.com/user-attachments/assets/a99c14ee-aef7-43a6-8dee-5169a7886b18" />

## How it works

After each Claude response, a Haiku agent reads the conversation context via `--continue` and generates a 2-4 word lowercase phrase (e.g., "fixing auth bug", "adding api endpoint"). The phrase becomes your tmux window name.

- **Asynchronous**: Fires off another claude and uses haiku
- **Context-aware**: Has full conversation history via `--continue`
- **Graceful**: Silently skips if not in tmux or if anything fails

## Installation

Using Claude Code slash commands:

```
/plugin marketplace add git@github.com:cosgroveb/claude-tmux-namer.git
/plugin install tmux-window-namer@claude-tmux-namer
```

Or clone and install manually:

```bash
git clone git@github.com:cosgroveb/claude-tmux-namer.git
cd claude-tmux-namer
make install
```

## Uninstallation

```
/plugin uninstall tmux-window-namer
/plugin marketplace remove claude-tmux-namer
```

Or manually:

```bash
cd claude-tmux-namer
make uninstall
```

## Requirements

- Claude Code CLI
- tmux

## FAQ

### How much does this cost?

Each rename uses Claude Haiku, the cheapest Claude model. Costs depend on whether Claude Code's context is cached:

| Scenario | Cost | When it happens |
|----------|------|-----------------|
| Cached | ~$0.003 | Most calls—when you're actively working |
| Not cached | ~$0.03-0.05 | First call in a session, or after ~5 min idle |

**Why the difference?** Claude Code sends ~30K tokens of system context with each API call. The API caches this context for ~5 minutes. Cached reads cost 1/10th as much. Since you're typically making multiple Claude requests while working, most rename calls hit the cache.

**Typical monthly cost:**
- Light use: pennies
- Heavy use: a few dollars

### Can I monitor costs?

Costs are logged to `~/.local/share/claude-tmux-namer/cost.log`:

```
2026-01-18T16:31:27+00:00 cost=$0.003 input=3 output=6 cache_read=25546 cache_create=520 name="fixing auth bug"
```

The `cache_read` and `cache_create` fields show how many tokens were read from vs written to the cache.

## License

MIT
