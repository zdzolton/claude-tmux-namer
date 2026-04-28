.PHONY: install uninstall clean reinstall test

PLUGIN_NAME := tmux-window-namer
MARKETPLACE_NAME := claude-tmux-namer

install:
	@echo "Adding marketplace..."
	claude plugin marketplace add "$(shell pwd)"
	@echo "Installing plugin..."
	claude plugin install $(PLUGIN_NAME)@$(MARKETPLACE_NAME)
	@echo "Done. Restart Claude to activate the plugin."

uninstall:
	@echo "Uninstalling plugin..."
	-claude plugin uninstall $(PLUGIN_NAME)
	@echo "Removing marketplace..."
	-claude plugin marketplace remove $(MARKETPLACE_NAME)
	@echo "Done."

clean:
	@echo "Cleaning up..."
	-claude plugin uninstall $(PLUGIN_NAME) 2>/dev/null || true
	-claude plugin marketplace remove $(MARKETPLACE_NAME) 2>/dev/null || true
	@echo "Done."

reinstall: clean install

test:
	@echo "Checking zsh syntax..."
	@zsh -n scripts/tmux-namer-start.zsh && echo "  ✓ tmux-namer-start.zsh"
	@zsh -n scripts/tmux-namer.zsh && echo "  ✓ tmux-namer.zsh"
	@echo "Validating plugin manifest..."
	@claude plugin validate ./ && echo "  ✓ plugin.json"
	@echo "All checks passed."
