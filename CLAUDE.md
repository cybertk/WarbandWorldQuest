# WarbandWorldQuest

UI addon for World of Warcraft Retail. It tracks world quests across every character in your
warband so you can see, in one place, which quests are still available or already completed on
each alt and which rewards they offer — without logging into each character. It adds a tab to the
Quest Log and enhances the world map pins.

## Tech Stack

- **Lua** (WoW runtime) — the version shipped with Retail; no external Lua tooling required to run.
- **WoW API** — Blizzard's frame/widget system, C_-namespaced APIs, and map-canvas data-provider
  mixins (`CreateFromMixins`, `hooksecurefunc`, `QuestMapFrame`, `WorldMapFrame`).
- **StyLua** — formatter. Run `make format` (there is no `stylua.toml`; the Makefile invokes
  `stylua --glob "**/*.lua" .` with StyLua defaults plus `.editorconfig`).

## Layout / Load Order

`.toc` and XML files declare the load order — Lua files are **not** auto-discovered.

- `WarbandWorldQuest.toc` — interface versions, SavedVariables, and the include list. Loads
  `Locales/Locales.xml`, `Core/Core.xml`, `UI/UI.xml`, then `WarbandWorldQuest.lua`.
- `Core/Core.xml` — orders the `Core/` modules (Util → Settings → RewardTypes → QuestRewards →
  WorldQuest → Character → CharacterStore). A module must load after anything it references at file
  scope; update this file when adding a `Core/` module.
- `UI/UI.xml` → `UI/DataProviders.xml` + `UI/WarbandWorldQuestMapFrame.xml`. Frame/template
  definitions live in the `.xml`; behavior lives in the matching `.lua`.
- `Locales/` — one file per locale (`enUS.lua` is the base), wired through `Locales/Locales.xml`.

```
WarbandWorldQuest.lua   — entry point: event routing, /wwq slash command, Init/Update loop
Core/                   — data layer: Util, Settings, RewardTypes, QuestRewards, WorldQuest,
                          Character, CharacterStore
UI/                     — map frame, quest-log page, data providers, settings button
Locales/                — localized strings
Embeds/                 — external libs vendored at package time (see .pkgmeta)
```

`Embeds/WeeklyRewards` and `Embeds/Dashi` are external dependencies pulled in by the BigWigs
packager from `.pkgmeta` — they are not part of this repo's source and are not edited here.

## Code Conventions

- **Tab indentation** (see `.editorconfig`: `indent_style = tab`, width 8, `max_line_length = 170`).
- **Module pattern**: each file starts with `local _, namespace = ...` (or
  `local addonName, ns = ...` in the entry point), pulls its dependencies off the namespace at the
  top (`local Util = ns.Util`), and **exports by assigning onto the namespace** at the bottom:
  `namespace.ModuleName = ModuleName`. Modules do **not** `return`.
- **PascalCase** for modules and for methods/functions, matching Blizzard's mixin style:
  `CharacterStore`, `Character:New`, `Settings:RegisterSettings`, and local helpers like
  `CreateCharacterSorter`.
- **camelCase** for variables and fields: `activePins`, `questsOnMap`, `dataProvider`.
- **Prefix unused args with `_`**: `function(_event, ...)`.
- **Access WoW globals directly** — `CreateFrame`, `C_Timer`, `hooksecurefunc`, `GetServerTime`,
  etc. are called by their bare global names (this codebase does **not** wrap them in `_G.`).
- **Localized strings** go through the locale tables, not hard-coded English literals.

## Formatting

```bash
make format   # runs StyLua over all *.lua files
```

There is no luacheck config and no separate lint step — StyLua formatting is the bar. Keep the tree
clean before committing.

## Build / Package

```bash
make build    # runs the BigWigsMods packager release.sh (fetches externals, builds the zip)
```

Packaging is driven by `.pkgmeta` (package name, externals, and the ignore list). Releases are
produced by `.github/workflows/release.yml`; the version comes from the `@project-version@` token
substituted at package time (do not hard-code a version in the `.toc`).

## Runtime Notes

- **SavedVariables**: `WarbandWorldQuestDB` (quests + per-character reward data) and
  `WarbandWorldQuestSettings` (user options). Defaults are defined in the `ADDON_LOADED` handler in
  `WarbandWorldQuest.lua`; add new settings to `DefaultWarbandWorldQuestSettings` there.
- **Slash commands**: `/wwq` and `/WarbandWorldQuest` (`/wwq debug` toggles debug logging).
- **Entry flow**: `ADDON_LOADED` sets up defaults → `PLAYER_ENTERING_WORLD` (initial login /
  reload) calls `WarbandWorldQuest:Init` → `QUEST_LOG_UPDATE` drives incremental `:Update`.
- Settings changes are propagated via `Settings:RegisterCallback` /
  `Settings:InvokeAndRegisterCallback`; prefer these over polling.

## Lua Practices

- **Localize** module references and hot-path globals (`local pairs = pairs`, `local tinsert = ...`)
  at the top of files that use them in loops.
- **Guard frame/method access** — WoW frames and Blizzard mixins may be nil at a given point; check
  `if obj and obj.Method then` before calling into optional UI.
- **Early returns over deep nesting.**
- **`ipairs` for arrays, `pairs` for dictionaries** — never `pairs` over a sequence you iterate in
  order.
- **Avoid churning tables in tight loops** (map scans, pin updates run frequently) — reuse tables
  and build outside the loop where possible.
- **Every variable is `local`** unless it is an intentional addon-scoped global (e.g. the frames and
  mixins Blizzard's XML templates expect by name, or the `WarbandWorldQuest` global itself).
