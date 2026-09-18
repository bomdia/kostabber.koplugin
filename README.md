# kostabber.koplugin

KoStabber è un plugin KOReader che indicizza feed OPDS e crea stub `.kocloud` per l'apertura remota dei libri.

## Moduli principali

- `main.lua`: bootstrap plugin + first-run wizard
- `wizard.lua`: configurazione iniziale sorgenti OPDS
- `sources.lua`: persistenza sorgenti in `sources.lua`
- `opds.lua`: fetch + parsing feed OPDS + generazione stub
- `stub.lua`: schema/storaging `.kocloud`
- `cover_cache.lua`: cache cover in `cache/covers/`
- `list_renderer.lua`: title/subtitle/badge renderer data
- `storage.lua`: policy engine (`none`, `manual_unlimited`, `fifo_cap`, `smart_inactivity`)
- `reader_hook.lua`: intercetta apertura `.kocloud`, download asset, progress sync
- `context_menu.lua`: azioni long-press su stub

## Layout dati locale

Configurabile con variabile `KOSTABBER_HOME` (default `~/.config/koreader/kostabber`):

- `sources.lua`
- `state.lua`
- `sync/*.kocloud`
- `cache/covers/*`
- `assets/*`
- `storage_ledger.json`
