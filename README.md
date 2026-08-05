# Exp Share

Party-wide experience from the OPTIONS menu, in Gen 1 Exp. All style, Gen 5+ Exp. Share style, or BALANCED / AVERAGE presets — with one "EXP is shared amongst the party" line instead of a gain message per Pokemon. A SINGLE EXP SHARE row can scope the shared exp to one party slot instead of the whole bench.

## How to try it

1. Install the mod and enable it in the mod manager (MODS row in OPTIONS).
2. Open OPTIONS and cycle the new EXP SHARE row with LEFT/RIGHT: OFF / GEN 1 / GEN 5+ / BALANCED / AVERAGE.
3. Fight. In GEN 1, the fighters split half the exp and the whole party splits the other half (the vanilla Exp. All split, including its division bug). In GEN 5+, the fighters keep the full exp and every alive bench mon gets half a fighter's share.
4. BALANCED is the GEN 5+ split with a level gate: a bench mon only gains exp while it is below the active fighter's level, so the bench trails the party instead of out-leveling the mons that actually fight. AVERAGE is the same gate measured against the party's average level (whole party, floored) instead of the active fighter. At- or over-threshold bench mons wait for the party to level past them.
5. The SINGLE EXP SHARE row (right below EXP SHARE) cycles ALL / 1 / 2 / 3 / 4 / 5 / 6. ALL (the default) shares with the whole bench; a slot number shares only with the Pokemon in that party slot — pick a slot past the party's size and nothing is shared at all. The fighters keep their own gain lines in every mode.
6. Shared recipients get one "EXP is shared amongst the party" line; the fighters still get their own "X gained N EXP. Points!" lines, and everyone's level-ups, stat boxes and move learning still show.

## Notes

- The setting is per save (stored in the save's options) and persists like every other options row.
- Bench mons gain half the stat experience too, since the engine splits stat exp with the same divisor.
- OFF restores vanilla behavior exactly, including the vanilla EXP. All item's per-mon messages.

## Layout

- `manifest.json` — identity, version range, load order
- `main.lua` — the entry chunk; the OPTIONS row and the exp split hook
- `tests/exp_share_test.lua` — headless coverage of the row and the splits

## Loop

1. `POKEPORT_DEV=1 love .` once, leave it running
2. edit, press F5 to hot-reload, backtick for the dev console
3. `python3 tools/modkit.py validate exp_share` before sharing
4. `python3 tools/modkit.py pack mods/exp_share` to ship
