# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

**Codebusters of SPLORR!!**: Farkle played against a hidden Mastermind code. A prototype by TheGrumpyGameDev, started November 15, 2026. Odin compiled to `js_wasm32`, a plain DOM page of text and buttons (no canvas).

`DESIGN.md` holds the user's decisions and the prototype defaults still open. Do not change rules or wording as settled without the user; only the user moves an item to Decided.

The vault at `/home/yermom/git/bok-of-splorr/splorr/` holds the standing rules for all SPLORR!! games; read its `Home.md` first. This game's note is `Games/Codebusters of SPLORR!!.md`; update it (and its `Home.md` row) when facts change.

## Commands

```bash
tools/test.sh            # native tests (odin test, one thread), then the real wasm build
tools/build.sh [--size]  # wasm build into build/web
tools/serve.sh           # build and serve on http://localhost:${PORT:-8000}/
tools/pages.sh           # tests, size build, copy into docs/ for GitHub Pages; never commits or pushes
```

## Architecture (package `codebusters` in `odin/`)

- `rules.odin`: the pure game (`Game`, `roll`, `select_slot`, `check`, `bank`, `next_turn`, `score_guess`), with its own xorshift generator seeded by the platform.
- `screens.odin`: the view model. `make_view` lists elements (`Elem_Kind`) for the current `Screen`; `click(action)` runs buttons and slot taps. Strings are in the temp allocator.
- `web.odin` (`#+build js`): imports `now_ms` (seed only) and `dom_clear/dom_add/dom_end`; exports `on_click(action)`.
- `web/index.html`: renders the elements as DOM (`textContent` only). **Its `KIND` table must match `Elem_Kind`**; `element_kinds_match_the_page` pins the count.
- Tests are `*_test.odin` (`#+build !js`).

## Release

Not released. Per the vault, new games start at GitHub Pages before itch.io is decided; making the repo public, enabling Pages and pushing are the user's call. The Release standard material (`ITCH_DESCRIPTION.md`, cover, screenshots, `tools/ship.sh`, `shippit.sh`) is not made yet. The footer's LootLocker "Send feedback" link is wired but hidden until `LL_DOMAIN` and `LL_KEY` are filled in.

## Rules

- Never `git push` or ship unless the user says so. "Push" means `git push`; "ship" means itch.io, one release a day through Coxswain.
- On itch.io and in page copy the game is a "Metaphor", never a "Game". Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" a deliberate design choice as a problem.
