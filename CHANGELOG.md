# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-08-05

### Added

- SINGLE EXP SHARE row in the OPTIONS menu, under EXP SHARE: cycle ALL / 1 / 2 / 3 / 4 / 5 / 6. Set to a slot number, the shared exp goes only to the Pokemon in that party slot instead of the whole bench; the fighters keep their own gain either way. ALL (the default) keeps the party-wide split. The GEN 1, GEN 5+, BALANCED and AVERAGE splits all honour the slot.

## [0.1.4] - 2026-08-05

### Changed

- The EXP SHARE row cycler now advances the mode with a direct index
  lookup instead of scanning the mode list linearly. Same behaviour.

## [0.1.3] - 2026-08-02

### Added

- AVERAGE preset in the EXP SHARE row (OFF / GEN 1 / GEN 5+ / BALANCED / AVERAGE): the GEN 5+ split with the same level gate as BALANCED, but measured against the party's average level (whole party, floored) instead of the active fighter's -- a bench Pokemon only gains exp while it is below that average.

## [0.1.2] - 2026-08-02

### Added

- BALANCED preset in the EXP SHARE row (OFF / GEN 1 / GEN 5+ / BALANCED): the GEN 5+ split with a level gate -- a bench Pokemon only gains exp while it is below the active fighter's level, so the bench trails the party instead of out-leveling the mons that actually fight. At-level or over-leveled bench mons get nothing until the fighter levels past them.

### Changed

- The shared-exp line now reads "EXP is shared amongst the party!" (EXP capitalised).

## [0.1.1] - 2026-08-02

### Fixed

- The "Exp is shared amongst the party" line now appears right after the participating Pokemon's own gains, before the bench Pokemon's level-up and move-learn messages (previously the bench level-ups queued before the share announcement).

## [0.1.0] - 2026-08-02

### Added

- EXP SHARE row in the OPTIONS menu cycling OFF / GEN 1 / GEN 5+.
- GEN 1 mode: the fighters split half the exp, the whole party splits the other half (vanilla Exp. All behavior, division bug included).
- GEN 5+ mode: the fighters keep the full exp; every alive bench mon gets half a fighter's share.
- One "Exp is shared amongst the party" line replaces the per-mon gain messages for shared exp; level-ups and move learning still show per mon.
