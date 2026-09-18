# kostabber.koplugin

KoStabber è un plugin KOReader che indicizza feed OPDS e crea stub `.kocloud` per l'apertura remota dei libri.

## Moduli principali

- `main.lua`: bootstrap plugin + first-run wizard
- `wizard.lua`: configurazione iniziale sorgenti OPDS
- `sources.lua`: persistenza sorgenti in `sources.json`
- `opds.lua`: fetch + parsing feed OPDS + generazione stub
- `stub.lua`: schema/storage `.kocloud`
- `cover_cache.lua`: cache cover in `cache/covers/`
- `list_renderer.lua`: title/subtitle/badge renderer data
- `storage.lua`: policy engine (`none`, `manual_unlimited`, `fifo_cap`, `smart_inactivity`)
- `reader_hook.lua`: intercetta apertura `.kocloud`, download asset, progress sync
- `context_menu.lua`: azioni long-press su stub

## Layout dati locale

Configurabile con variabile `KOSTABBER_HOME` (default `~/.config/koreader/kostabber`):

- `sources.json`
- `state.json`
- `sync/*.kocloud`
- `cache/covers/*`
- `assets/*`
- `storage_ledger.json`

## VS Code

La cartella `.vscode/` include:

- `extensions.json`: estensioni consigliate (LuaLS, EditorConfig)
- `settings.json`: associazioni file e runtime Lua 5.1
- `tasks.json`: task rapidi per syntax check, test focalizzati e build release

## Build release plugin

Comandi principali:

- `make syntax-check`
- `make test`
- `make release-build`

Output:

- `kostabber.koplugin-<version>.zip` pronto da installare/testare su KOReader.

## Coder

`.coder/` contiene un template Terraform per creare un workspace Coder
Docker-based con Lua 5.1, `make` e `zip` preinstallati. Per istruzioni su
deploy e accesso al workspace, vedere `.coder/README.md`.
