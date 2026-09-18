.PHONY: help syntax-check test release-build clean

PLUGIN_DIR := kostabber.koplugin
LUA := $(shell command -v lua 2>/dev/null || command -v lua5.1 2>/dev/null)
LUAC := $(shell command -v luac 2>/dev/null || command -v luac5.1 2>/dev/null)
VERSION := $(shell $(LUA) -e 'local m=dofile("metadata.lua"); io.write(m.version or "0.0.0")')
ARTIFACT := $(PLUGIN_DIR)-$(VERSION).zip
ROOT_FILES := README.md LICENSE \
	main.lua metadata.lua notify.lua opds.lua paths.lua reader_hook.lua \
	sources.lua storage.lua stub.lua util.lua wizard.lua list_renderer.lua cover_cache.lua context_menu.lua

help:
	@echo "Targets:"
	@echo "  make syntax-check   # Lua syntax validation"
	@echo "  make test           # Focused test suite"
	@echo "  make release-build  # Build release zip artifact"
	@echo "  make clean          # Remove build artifacts"

syntax-check:
	@test -n "$(LUAC)" || (echo "luac non trovato (installa lua5.1)"; exit 1)
	@for f in *.lua tests/*.lua; do \
		$(LUAC) -p "$$f" || exit 1; \
	done

test:
	@test -n "$(LUA)" || (echo "lua non trovato (installa lua5.1)"; exit 1)
	@cd tests && $(LUA) main_test.lua && $(LUA) reader_hook_test.lua && $(LUA) wizard_test.lua

release-build: syntax-check test
	@test -n "$(LUA)" || (echo "lua non trovato (installa lua5.1)"; exit 1)
	@mkdir -p dist/$(PLUGIN_DIR)
	@for f in $(ROOT_FILES); do cp "$$f" "dist/$(PLUGIN_DIR)/"; done
	@(cd dist && zip -rq "../$(ARTIFACT)" "$(PLUGIN_DIR)")
	@rm -rf dist
	@echo "Built $(ARTIFACT)"

clean:
	@rm -rf dist
	@rm -f $(PLUGIN_DIR)-*.zip
