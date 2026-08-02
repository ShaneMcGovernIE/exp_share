# Exp Share

Party-wide experience from the OPTIONS menu, in Gen 1 Exp. All style or Gen 5+ Exp. Share style — with one "EXP is shared amongst the party" line instead of a gain message per Pokemon.

## How to try it

1. Install the mod and enable it in the mod manager (MODS row in OPTIONS).
2. Open OPTIONS and cycle the new EXP SHARE row with LEFT/RIGHT: OFF / GEN 1 / GEN 5+.
3. Fight. In GEN 1, the fighters split half the exp and the whole party splits the other half (the vanilla Exp. All split, including its division bug). In GEN 5+, the fighters keep the full exp and every alive bench mon gets half a fighter's share.
4. Shared recipients get one "EXP is shared amongst the party" line; the fighters still get their own "X gained N EXP. Points!" lines, and everyone's level-ups, stat boxes and move learning still show.

## Notes

- The setting is per save (stored in the save's options) and persists like every other options row.
- Bench mons gain half the stat experience too, since the engine splits stat exp with the same divisor.
- OFF restores vanilla behavior exactly, including the vanilla EXP. All item's per-mon messages.

## Layout

- `manifest.json` — identity, version range, load order
- `main.lua` — the entry chunk; the OPTIONS row and the exp split hook
- `tests/exp_share_test.lua` — headless coverage of the row and both splits

## Loop

1. `POKEPORT_DEV=1 love .` once, leave it running
2. edit, press F5 to hot-reload, backtick for the dev console
3. `python3 tools/modkit.py validate exp_share` before sharing
4. `python3 tools/modkit.py pack mods/exp_share` to ship
